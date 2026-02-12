"""Load IT procurement data from SCPRS (State Procurement Registry System) and LPA contracts."""

from __future__ import annotations

import json
import os
import re
import tempfile
import time
import warnings
from datetime import datetime, timedelta
from typing import Dict, List, Optional

import pandas as pd
import pendulum
import requests
from bs4 import BeautifulSoup
from bs4 import XMLParsedAsHTMLWarning
from common.defaults import DEFAULT_ARGS
from snowflake.connector.pandas_tools import write_pandas

from airflow.decorators import dag, task
from airflow.operators.python import get_current_context
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

# Suppress XMLParsedAsHTMLWarning from BeautifulSoup
warnings.filterwarnings("ignore", category=XMLParsedAsHTMLWarning)

MAX_PAGES = 300


class SCPRSScraper:
    """HTTP-based scraper for SCPRS using the direct PeopleSoft endpoint."""

    BASE_URL = "https://suppliers.fiscal.ca.gov"
    SEARCH_PAGE = "/psc/psfpd1/SUPPLIER/ERP/c/ZZ_PO.ZZ_SCPRS1_CMP.GBL"

    def __init__(self, debug=False):
        self.debug = debug
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:147.0) Gecko/20100101 Firefox/147.0",
                "Accept": "*/*",
                "Accept-Language": "en-US,en;q=0.9",
                "Content-Type": "application/x-www-form-urlencoded",
                "Origin": self.BASE_URL,
                "Connection": "keep-alive",
            }
        )
        self.icsid = None
        self.icstate_num = None
        self._initialize_session()

    def _log(self, message):
        """Log debug messages if debug mode is enabled."""
        if self.debug:
            print(f"[DEBUG] {message}")

    def _initialize_session(self):
        """Load the search page to establish session and extract tokens."""
        try:
            url = f"{self.BASE_URL}{self.SEARCH_PAGE}"
            self._log(f"Loading initial page: {url}")

            response = self.session.get(url, timeout=30)
            response.raise_for_status()

            self._log(f"Page loaded: {len(response.text)} bytes")
            self._log(f"Cookies: {list(self.session.cookies.keys())}")

            # Extract ICSID and ICStateNum from the HTML
            self._extract_tokens_from_html(response.text)

            # Update referer for future requests
            self.session.headers["Referer"] = url

        except Exception as e:
            print(f"Error initializing session: {e}")

    def _fill_field(self, field_name: str, value: str):
        """Simulate filling in a form field to update PeopleSoft state.

        This triggers validation and increments ICStateNum.
        """
        url = f"{self.BASE_URL}{self.SEARCH_PAGE}"
        form_data = self._base_form_data(field_name)
        # Override specific fields for field-fill action
        form_data["ICActionPrompt"] = "false"
        form_data["ICBcDomData"] = ""
        form_data[field_name] = value

        try:
            response = self.session.post(url, data=form_data, timeout=30)
            response.raise_for_status()

            # Extract the new state number from the response
            match = re.search(r"ICStateNum\.value=(\d+)", response.text)
            if match:
                self.icstate_num = match.group(1)
                self._log(f"State updated to: {self.icstate_num}")
        except Exception as e:
            self._log(f"Error filling field: {e}")

    def _extract_tokens_from_html(self, html):
        """Extract ICSID and ICStateNum from the page HTML."""
        # Try to find ICSID
        icsid_patterns = [
            r'name=["\']ICSID["\'][^>]*value=["\']([^"\']+)["\']',
            r'"ICSID"\s*:\s*"([^"]+)"',
            r'id=["\']ICSID["\'][^>]*value=["\']([^"\']+)["\']',
        ]

        for pattern in icsid_patterns:
            match = re.search(pattern, html, re.IGNORECASE)
            if match:
                self.icsid = match.group(1)
                self._log(f"Extracted ICSID: {self.icsid}")
                break

        if not self.icsid:
            # Try to find it in a script tag
            script_match = re.search(
                r'var\s+ICSID\s*=\s*["\']([^"\']+)["\']', html, re.IGNORECASE
            )
            if script_match:
                self.icsid = script_match.group(1)
                self._log(f"Extracted ICSID from script: {self.icsid}")

        # Try to find ICStateNum
        icstate_patterns = [
            r'name=["\']ICStateNum["\'][^>]*value=["\']([^"\']+)["\']',
            r'"ICStateNum"\s*:\s*"([^"]+)"',
            r'id=["\']ICStateNum["\'][^>]*value=["\']([^"\']+)["\']',
        ]

        for pattern in icstate_patterns:
            match = re.search(pattern, html, re.IGNORECASE)
            if match:
                self.icstate_num = match.group(1)
                self._log(f"Extracted ICStateNum: {self.icstate_num}")
                break

    def search(
        self,
        department: Optional[str] = None,
        acquisition_type: Optional[str] = None,
        start_date_from: Optional[str] = None,
        start_date_to: Optional[str] = None,
    ) -> pd.DataFrame:
        """Perform a search on SCPRS using working server-side filters.

        Request sequence:
        1. GET: Initialize session (done in __init__)
        2. POST: Fill acquisition type field (if provided)
        3. POST: Execute search with other parameters
        4. POST: Automatically fetch all pages if pagination exists

        Args:
            department: Department code (e.g., '3540' for CAL FIRE)
            acquisition_type: Acquisition Type (e.g., 'IT Goods')
            start_date_from: Start date from (MM/DD/YYYY)
            start_date_to: Start date to (MM/DD/YYYY)

        Returns:
            DataFrame with procurement records
        """
        # Acquisition type requires field-fill step for server-side filtering
        if acquisition_type:
            self._log(f"Filling Acquisition Type field: {acquisition_type}")
            self._fill_field("ZZ_SCPRS_SP_WRK_ZZ_ACQ_TYPE", acquisition_type)
            self._log(f"Acquisition Type filled, state is now: {self.icstate_num}")

        # Build the form data for the search
        form_data = self._build_form_data(
            department=department,
            start_date_from=start_date_from,
            start_date_to=start_date_to,
        )

        url = f"{self.BASE_URL}{self.SEARCH_PAGE}"
        self._log(f"Posting search to {url}")
        self._log(
            f"Search parameters: dept={department}, dates={start_date_from} to {start_date_to}"
        )
        if self.debug:
            # Show the actual form fields being sent
            search_fields = {k: v for k, v in form_data.items() if k.startswith("ZZ_")}
            if search_fields:
                self._log(f"Form search fields: {search_fields}")

        try:
            response = self.session.post(url, data=form_data, timeout=60)
            response.raise_for_status()

            self._log(f"Response status: {response.status_code}")
            self._log(f"Response length: {len(response.text)} bytes")

            # Extract updated ICStateNum from response
            self._extract_tokens_from_html(response.text)

            # Always follow pagination if available
            pages = [response.text]
            current_html = response.text
            page_num = 1

            while self._has_next_page(current_html):
                self._log(f"Fetching page {page_num + 1}...")
                next_response = self._fetch_next_page()

                if next_response.get("status") != "success":
                    self._log(
                        f"Error fetching page {page_num + 1}: {next_response.get('error')}"
                    )
                    break

                current_html = next_response["html"]
                pages.append(current_html)
                page_num += 1

                if page_num >= MAX_PAGES:  # Safety limit
                    self._log(f"Reached pagination safety limit ({MAX_PAGES} pages)")
                    break

            self._log(f"Fetched {len(pages)} total pages")

            # Parse all pages and return DataFrame
            return self._parse_results(pages)

        except requests.exceptions.RequestException as e:
            print(f"Error: {e}")
            return pd.DataFrame()

    def _base_form_data(self, action: str) -> Dict[str, str]:
        """Build base form data for PeopleSoft requests.

        Args:
            action: The ICAction value (e.g., 'ZZ_SCPRS_SP_WRK_BUTTON' for search)

        Returns:
            Base form data dict
        """
        return {
            "ICAJAX": "1",
            "ICNAVTYPEDROPDOWN": "0",
            "ICType": "Panel",
            "ICElementNum": "0",
            "ICStateNum": self.icstate_num or "1",
            "ICAction": action,
            "ICModelCancel": "0",
            "ICXPos": "0",
            "ICYPos": "0",
            "ResponsetoDiffFrame": "-1",
            "TargetFrameName": "None",
            "FacetPath": "None",
            "ICFocus": "",
            "ICSaveWarningFilter": "0",
            "ICChanged": "-1",
            "ICSkipPending": "0",
            "ICAutoSave": "0",
            "ICResubmit": "0",
            "ICSID": self.icsid or "",
            "ICActionPrompt": "true",
            "ICBcDomData": "UnknownValue",
            "ICPanelName": "",
            "ICFind": "",
            "ICAddCount": "",
            "ICAppClsData": "",
            "DUMMY_FIELD$hnewpers$0": "0|0|0|0|0|95|0#1|0|0|0|0|42|0#4|0|0|0|0|174|0#",
        }

    def _has_next_page(self, html: str) -> bool:
        """Check if there's a next page button available in the HTML."""
        soup = BeautifulSoup(html, "lxml")
        next_button = soup.find("a", id=re.compile(r"ZZ_SCPRS_SP_WRK_NEXT_BUTTON"))
        return next_button is not None

    def _fetch_next_page(self) -> Dict:
        """Fetch the next page of results."""
        url = f"{self.BASE_URL}{self.SEARCH_PAGE}"
        form_data = self._base_form_data("ZZ_SCPRS_SP_WRK_NEXT_BUTTON")

        try:
            response = self.session.post(url, data=form_data, timeout=60)
            response.raise_for_status()

            # Extract updated ICStateNum
            self._extract_tokens_from_html(response.text)

            return {
                "status": "success",
                "html": response.text,
            }

        except requests.exceptions.RequestException as e:
            return {"status": "error", "error": str(e)}

    def _build_form_data(
        self,
        department: Optional[str] = None,
        start_date_from: Optional[str] = None,
        start_date_to: Optional[str] = None,
    ) -> Dict[str, str]:
        """Build the form data for the search request.

        Note: acquisition_type is NOT included here - it's set via _fill_field()
        before this method is called, and the server remembers it in the session.
        """
        form_data = self._base_form_data("ZZ_SCPRS_SP_WRK_BUTTON")

        # Add search parameters (these work server-side)
        if department:
            form_data["ZZ_SCPRS_SP_WRK_BUSINESS_UNIT"] = department

        if start_date_from:
            form_data["ZZ_SCPRS_SP_WRK_FROM_DATE"] = start_date_from

        if start_date_to:
            form_data["ZZ_SCPRS_SP_WRK_TO_DATE"] = start_date_to

        return form_data

    def _parse_results(self, pages: List[str]) -> pd.DataFrame:
        """Parse HTML pages to extract procurement records.

        Args:
            pages: List of HTML page strings

        Returns:
            DataFrame with procurement records
        """
        all_records = []
        for page_num, html in enumerate(pages, 1):
            self._log(f"Parsing page {page_num}...")
            records = self._parse_html_page(html)
            all_records.extend(records)

        self._log(f"Total records across {len(pages)} page(s): {len(all_records)}")
        return pd.DataFrame(all_records)

    def _parse_html_page(self, html: str) -> List[Dict]:
        """Parse a single HTML page to extract records.

        Args:
            html: HTML content of the page

        Returns:
            List of record dictionaries
        """
        soup = BeautifulSoup(html, "lxml")

        # Look for the results table (ID: ZZ_SCPR_RSLT_VW$scroll$0)
        table = soup.find("table", {"id": "ZZ_SCPR_RSLT_VW$scroll$0"})

        if not table:
            self._log("No results table found")
            return []

        # Find all result rows (pattern: trZZ_SCPR_RSLT_VW$0_row0, trZZ_SCPR_RSLT_VW$0_row1, etc.)
        rows = table.find_all("tr", id=re.compile(r"trZZ_SCPR_RSLT_VW\$0_row\d+"))

        self._log(f"Found {len(rows)} result rows")

        records = []
        for row in rows:
            try:
                record = self._parse_row(row)
                if record:
                    records.append(record)
            except Exception as e:
                self._log(f"Error parsing row: {e}")
                continue

        return records

    # Field mapping: field_name -> (tag_type, id_pattern)
    FIELD_PATTERNS = {
        "purchase_doc": ("a", r"PURCHASE_DOC\$"),
        "description": ("span", r"ZZ_SCPR_RSLT_VW_DESCR254_MIXED\$"),
        "department": ("span", r"ZZ_SCPR_RSLT_VW_DESCR\$"),
        "supplier_id": ("span", r"ZZ_SCPR_RSLT_VW_SUPPLIER_ID\$"),
        "supplier_name": ("span", r"ZZ_SCPR_RSLT_VW_NAME1\$"),
        "start_date": ("span", r"ZZ_SCPR_RSLT_VW_START_DATE\$"),
        "end_date": ("span", r"ZZ_SCPRS_SP_WRK_END_DATE\$"),
        "grand_total": ("span", r"ZZ_SCPR_RSLT_VW_AWARDED_AMT\$"),
        "lpa_contract_id": ("span", r"ZZ_SCPR_RSLT_VW_ZZ_LPACONTRACTNBR\$"),
        "certification_type": ("span", r"ZZ_SCPR_RSLT_VW_ZZ_CERT_TYPE\$"),
        "acquisition_method": ("span", r"ZZ_SCPR_RSLT_VW_ZZ_ACQ_MTHD\$"),
        "buyer_name": ("span", r"BUYER_DESCR\$"),
        "buyer_email": ("span", r"ZZ_SCPR_RSLT_VW_EMAILID\$"),
        "acquisition_type": ("span", r"ZZ_SCPR_RSLT_VW_ZZ_COMMENT1\$"),
        "status": ("span", r"ZZ_SCPR_RSLT_VW_STATUS2\$"),
    }

    def _parse_row(self, row) -> Optional[Dict]:
        """Parse a single result row."""
        record = {}

        for field_name, (tag_type, pattern) in self.FIELD_PATTERNS.items():
            element = row.find(tag_type, id=re.compile(pattern))
            if element:
                record[field_name] = element.get_text(strip=True)

        return record if record else None


class LPAScraper:
    """Scraper for LPA data using the InFlight/PeopleSoft interface."""

    BASE_URL = "https://caleprocure.ca.gov"
    SEARCH_ENDPOINT = "/nlx3/psc/psfpd1/SUPPLIER/ERP/c/ZZ_PO.ZZ_CNT_SRC_CMP_BKP.GBL"

    # Common IF-TargetContent structure for most requests
    TARGET_CONTENT = [
        {
            "Lbl": "attachmentWrapper",
            "Src": "div.InFlightAttachment:first",
            "Data": "null",
            "HWA": ".",
            "Children": [
                {
                    "Lbl": "attachmentLink",
                    "Src": ".",
                    "Data": "text:href",
                    "Children": [],
                }
            ],
        },
        {
            "Lbl": "formAction",
            "Src": "form",
            "Data": "action:ifaction",
            "HWA": ".",
            "Children": [],
        },
        {
            "Lbl": "popupMessageContent",
            "Src": "span.InFlightPopup",
            "Data": "html",
            "Children": [],
        },
        {
            "Lbl": "genscripts",
            "Src": "script:contains('ICStateNum.value')",
            "Data": "html",
            "Children": [],
        },
        {
            "Lbl": "hiddenInput",
            "Src": "input[type=hidden]",
            "Data": "id name value",
            "Children": [],
        },
    ]

    def __init__(self, debug=False):
        self.debug = debug
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:147.0) Gecko/20100101 Firefox/147.0",
                "Accept": "application/json, text/javascript, */*; q=0.01",
                "Accept-Language": "en-US,en;q=0.9",
                "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                "Origin": self.BASE_URL,
                "Connection": "keep-alive",
            }
        )
        self.icsid = None
        self.icstate_num = None
        self.session_id = None
        self._initialize_session()

    def _log(self, message):
        """Log debug messages if debug mode is enabled."""
        if self.debug:
            print(f"[DEBUG] {message}")

    def _get_base_form_data(self) -> dict:
        """Get base form data template shared across requests."""
        return {
            "IF-TargetVerb": "POST",
            "IF-TargetContent": json.dumps(self.TARGET_CONTENT),
            "IF-Template": "/pages/LPASearch/lpa-search.aspx",
            "IF-IgnoreContent": "",
            "ICDoModal": "1",
            "sortAction": "",
            "ICType": "Panel",
            "ICElementNum": "0",
            "ICStateNum": self.icstate_num or "1",
            "ICAction": "",
            "ICModelCancel": "0",
            "ICXPos": "0",
            "ICYPos": "0",
            "ResponsetoDiffFrame": "-1",
            "TargetFrameName": "None",
            "FacetPath": "None",
            "ICFocus": "",
            "ICSaveWarningFilter": "0",
            "ICChanged": "-1",
            "ICSkipPending": "0",
            "ICAutoSave": "0",
            "ICResubmit": "0",
            "ICSID": self.icsid or "",
            "ICActionPrompt": "false",
            "ICBcDomData": "",
            "ICPanelName": "",
            "ICFind": "",
            "ICAddCount": "",
            "ICAppClsData": "",
            "ZZ_CTR_SRC_VW$hnewpers$0": "0|0|1|0|0|0|0#1|0|1|0|0|0|0#3|0|1|0|0|0|0#4|0|1|0|0|156|1#5|0|0|0|0|0|0#6|0|0|0|0|0|0#7|0|0|0|0|0|0#8|0|0|0|0|0|0#9|0|0|0|0|85|1#10|0|0|0|0|0|0#11|0|0|0|0|0|0#12|0|0|2|1|151|1#13|0|0|0|0|0|0#14|0|0|0|0|0|0#15|0|0|0|0|0|0#16|0|0|0|0|0|0#18|0|0|0|0|96|1#19|0|0|0|0|0|0#20|0|0|0|0|0|0#21|0|0|0|0|0|0#22|0|0|0|0|0|0#23|0|0|0|0|0|0#24|0|0|0|0|0|0#25|0|0|0|0|0|0#26|0|0|0|0|0|0#28|0|0|0|0|0|0#29|0|0|0|0|0|0#30|0|0|0|0|0|0#31|0|0|0|0|0|0#",
            "ZZ_CTR_SRC2_WRK_CNTRCT_ID": "",
            "DESCR_1": "",
            "ZZ_CTR_SRC2_WRK_ZZ_CNTRCT_TYPE": "",
            "ZZ_CTR_SRC2_WRK_BUYER_ID": "",
            "ZZ_CTR_SRC2_WRK_VENDOR_ID": "",
            "ZZ_CTR_SRC2_WRK_NAME1": "",
            "ZZ_CTR_SRC2_WRK_ZZ_ACQ_TYPE": "",
        }

    def _initialize_session(self):
        """Initialize session by loading the search page."""
        try:
            url = f"{self.BASE_URL}{self.SEARCH_ENDPOINT}"
            self._log(f"Initializing session: {url}")

            # First request - page load (GET-style initialization)
            form_data = {
                "IF-TargetVerb": "GET",
                "IF-TargetContent": json.dumps(self.TARGET_CONTENT),
                "IF-Template": "/pages/LPASearch/lpa-search.aspx",
                "IF-IgnoreContent": "",
                "ICDoModal": "1",
                "sortAction": "",
            }

            response = self.session.post(url, data=form_data, timeout=30)
            response.raise_for_status()

            self._log(f"Session initialized: {len(response.text)} bytes")

            # Extract session tokens from response
            self._extract_tokens(response)

            # Update referer for future requests
            self.session.headers["Referer"] = (
                "https://caleprocure.ca.gov/pages/LPASearch/lpa-search.aspx"
            )

            # Make a second request to fully initialize the page
            self._log("Making second initialization request...")
            response2 = self.session.post(url, data=form_data, timeout=30)
            response2.raise_for_status()
            self._extract_tokens(response2)
            self._log("Second initialization complete")

            # Small delay to avoid rate limiting
            time.sleep(1)

        except Exception as e:
            print(f"Error initializing session: {e}")

    def _extract_tokens(self, response):
        """Extract ICSID, ICStateNum, and session ID from response."""
        try:
            data = response.json()
            self._log(f"Response keys: {list(data.keys())}")

            # Check CaptureResults for hidden inputs (InFlight format)
            hidden_inputs = []
            if "CaptureResults" in data:
                capture = data["CaptureResults"]
                if "hiddenInput" in capture:
                    hidden_inputs = capture["hiddenInput"]
            elif "hiddenInput" in data:
                hidden_inputs = data["hiddenInput"]

            if hidden_inputs:
                self._log(f"Found {len(hidden_inputs)} hidden inputs")
                if self.debug and len(hidden_inputs) > 0:
                    # Log structure of first hidden input
                    self._log(f"Sample hidden input structure: {hidden_inputs[0]}")

                for item in hidden_inputs:
                    props = item.get("Properties", {})
                    item_id = props.get("id")
                    item_value = props.get("value")

                    if item_id == "ICSID":
                        self.icsid = item_value
                        self._log(f"Extracted ICSID: {self.icsid}")
                    elif item_id == "ICStateNum":
                        self.icstate_num = item_value
                        self._log(f"Extracted ICStateNum: {self.icstate_num}")
            else:
                self._log("No hiddenInput found")

            # Extract InFlightSessionID from cookies
            if "InFlightSessionID" in self.session.cookies:
                self.session_id = self.session.cookies["InFlightSessionID"]
                self._log(f"Session ID: {self.session_id}")

        except Exception as e:
            self._log(f"Error extracting tokens: {e}")

    def search(self, show_expired: bool = False) -> pd.DataFrame:
        """Perform a search on the LPA system and return results as a DataFrame.

        Args:
            show_expired: If True, returns expired contracts. If False, returns active contracts.

        Returns:
            DataFrame with LPA data
        """
        url = f"{self.BASE_URL}{self.SEARCH_ENDPOINT}"

        # Start with base form data and customize for search
        form_data = self._get_base_form_data()
        form_data["ICAction"] = "ZZ_CTR_SRC2_WRK_SEARCH_BTN"

        # Add expired contracts checkbox
        if show_expired:
            form_data["ZZ_CTR_SRC2_WRK_CHECKED"] = "Y"
            form_data["ZZ_CTR_SRC2_WRK_CHECKED$chk"] = "Y"

        try:
            # Step 1: Perform search request
            self._log(f"Performing search: expired={show_expired}")
            response = self.session.post(
                url, data=form_data, timeout=180
            )  # 3 minute timeout
            response.raise_for_status()

            self._log(f"Search response: {len(response.text)} bytes")

            data = response.json()

            # Update tokens from response
            self._extract_tokens(response)

            # Check if we have results
            if "CaptureResults" in data:
                capture = data["CaptureResults"]
                # Look for result indicators
                if "ZZ_CTR_SRC_VWGCCounter" in capture:
                    counter_data = capture["ZZ_CTR_SRC_VWGCCounter"]
                    if len(counter_data) > 0:
                        counter_text = (
                            counter_data[0].get("Properties", {}).get("text", "")
                        )
                        self._log(f"Result counter: {counter_text}")

                # Check for data rows
                if "ZZ_CTR_SRC_VWDataRow" in capture:
                    rows = capture["ZZ_CTR_SRC_VWDataRow"]
                    self._log(f"Found {len(rows)} data rows")

                # Check for "no results" message
                if "noRowsFoundText" in capture:
                    no_results = capture["noRowsFoundText"]
                    if len(no_results) > 0:
                        message = no_results[0].get("Properties", {}).get("text", "")
                        if message:
                            self._log(f"No results message: {message}")

            # Step 2: Download the Excel file
            tmp_path = self._download()

            # Step 3: Parse the HTML table (file is actually HTML, not true Excel)
            self._log(f"Parsing Excel file: {tmp_path}")
            df_list = pd.read_html(tmp_path)
            if not df_list:
                raise Exception("No tables found in downloaded file")
            df = df_list[0]  # Get first table
            self._log(f"Parsed {len(df)} rows, {len(df.columns)} columns")

            # Clean up temp file
            os.unlink(tmp_path)

            return df

        except Exception as e:
            print(f"Error during search: {e}")
            return pd.DataFrame()

    def _download(self) -> str:
        """Download search results as Excel file (internal method).

        Returns:
            Path to downloaded temporary file

        Raises:
            Exception: If download request fails or URL not found
        """
        url = f"{self.BASE_URL}{self.SEARCH_ENDPOINT}"

        self._log(f"Using ICStateNum: {self.icstate_num}")

        # Step 1: Request download URL
        form_data = self._get_base_form_data()
        form_data["ICAction"] = "ZZ_CTR_SRC_VW$hexcel$0"  # Excel download action
        form_data["ZZ_CTR_SRC_VW$hnewpers$0"] = (
            "0|0|1|0|0|0|0#1|0|1|0|0|0|0#3|0|1|0|0|0|0#4|0|1|0|0|156|1#5|0|0|0|0|0|0#6|0|0|0|0|0|0#7|0|0|0|0|0|0#8|0|0|0|0|103|0#9|0|0|0|0|85|1#10|0|0|0|0|99|0#11|0|0|0|0|0|0#12|0|0|2|1|151|1#13|0|0|0|0|71|0#14|0|0|0|0|113|0#15|0|0|0|0|67|0#16|0|0|0|0|67|0#18|0|0|0|0|96|1#19|0|0|0|0|51|0#20|0|0|0|0|0|0#21|0|0|0|0|0|0#22|0|0|0|0|0|0#23|0|0|0|0|0|0#24|0|0|0|0|0|0#25|0|0|0|0|0|0#26|0|0|0|0|0|0#28|0|0|0|0|0|0#29|0|0|0|0|0|0#30|0|0|0|0|0|0#31|0|0|0|0|0|0#"
        )
        form_data["ZZ_CTR_SRC2_WRK_CHECKED"] = "Y"
        form_data["ZZ_CTR_SRC2_WRK_CHECKED$chk"] = "Y"

        self._log("Requesting Excel download...")
        response = self.session.post(url, data=form_data, timeout=60)
        response.raise_for_status()

        self._log(f"Download response: {len(response.text)} bytes")

        data = response.json()

        # Extract download URL from attachmentLink in CaptureResults
        download_url = None
        if "CaptureResults" in data and "attachmentWrapper" in data["CaptureResults"]:
            attachment_wrappers = data["CaptureResults"]["attachmentWrapper"]
            if len(attachment_wrappers) > 0:
                wrapper = attachment_wrappers[0]
                children = wrapper.get("Children", {})
                if "attachmentLink" in children:
                    attachment_links = children["attachmentLink"]
                    self._log(f"Found {len(attachment_links)} attachment links")
                    if len(attachment_links) > 0:
                        link_data = attachment_links[0]
                        props = link_data.get("Properties", {})
                        if "href" in props:
                            download_url = props["href"]
                            self._log(f"Download URL: {download_url}")

        if not download_url:
            raise Exception("No download URL found in response")

        # Step 2: Download the file
        self._log("Downloading file...")
        response = self.session.get(download_url, timeout=60)
        response.raise_for_status()

        # Step 3: Save to temporary file
        with tempfile.NamedTemporaryFile(
            mode="wb", suffix=".xls", delete=False
        ) as tmp_file:
            tmp_file.write(response.content)
            tmp_path = tmp_file.name

        self._log(f"Downloaded {len(response.content)} bytes to {tmp_path}")
        return tmp_path


def get_date_range(context) -> tuple[pendulum.DateTime, pendulum.DateTime]:
    """
    Calculate 1-year lookback from data_interval_end.

    For a monthly DAG running on Feb 1:
    - data_interval_end = 2025-02-01 (end of January interval)
    - Returns: 2024-02-01 to 2025-02-01 (inclusive)

    For backfill triggered with logical_date=2005-12-01:
    - data_interval_end = 2006-01-01 (one month after logical_date)
    - Returns: 2005-01-01 to 2006-01-01
    """
    end = context["data_interval_end"]
    # Subtract exactly 1 year
    start = end.subtract(years=1)

    return start, end


def transform_scprs_data(df: pd.DataFrame) -> pd.DataFrame:
    """Transform scraped data for Snowflake."""
    df = df.copy()

    # Parse dates: MM/DD/YYYY strings -> datetime, then convert to Python date objects
    df["start_date"] = pd.to_datetime(
        df["start_date"], format="%m/%d/%Y", errors="coerce"
    ).dt.date
    df["end_date"] = pd.to_datetime(
        df["end_date"], format="%m/%d/%Y", errors="coerce"
    ).dt.date

    # Parse grand_total: "$1,234.56" -> 1234.56
    df["grand_total"] = (
        df["grand_total"]
        .str.replace("$", "", regex=False)
        .str.replace(",", "", regex=False)
        .astype(float)
    )

    # Uppercase columns for Snowflake convention
    df.columns = df.columns.str.upper()

    # Add load timestamp
    df["LOADED_AT"] = datetime.now()

    return df


@task
def scrape_scprs() -> str:
    """Scrape SCPRS data for date range and write to /tmp."""
    # Get date range from context
    context = get_current_context()
    start_date, end_date = get_date_range(context)

    scraper = SCPRSScraper(debug=False)

    # Format dates for scraper API (MM/DD/YYYY)
    start_str = start_date.strftime("%m/%d/%Y")
    end_str = end_date.strftime("%m/%d/%Y")

    # Scrape for both IT acquisition types
    acquisition_types = ["IT Goods", "IT Services"]
    dfs = []

    for acq_type in acquisition_types:
        print(f"Scraping {acq_type} from {start_str} to {end_str}")
        df = scraper.search(
            acquisition_type=acq_type,
            start_date_from=start_str,
            start_date_to=end_str,
        )
        # Explicitly set acquisition_type column
        df["acquisition_type"] = acq_type
        print(f"  Found {len(df)} records for {acq_type}")
        dfs.append(df)

    # Combine results
    combined_df = pd.concat(dfs, ignore_index=True)
    print(f"Total records (before dedup): {len(combined_df)}")

    # Deduplicate on composite key (keep last occurrence)
    # Note: purchase_doc is reused across departments, so (purchase_doc, department) is the true primary key
    combined_df = combined_df.drop_duplicates(
        subset=["purchase_doc", "department"], keep="last"
    )
    print(f"Total records (after dedup): {len(combined_df)}")

    # Write to /tmp and return file path
    file_path = f"/tmp/scprs_{context['dag_run'].run_id}.parquet"
    combined_df.to_parquet(file_path, index=False)
    print(f"Wrote {len(combined_df)} records to {file_path}")

    return file_path


@task
def load_to_snowflake(file_path: str) -> None:
    """Load to Snowflake with DELETE + INSERT strategy."""
    # Get date range from context
    context = get_current_context()
    start_date, end_date = get_date_range(context)

    # Read dataframe from /tmp
    df = pd.read_parquet(file_path)
    print(f"Read {len(df)} records from {file_path}")

    # Transform data types (dates, currency)
    df = transform_scprs_data(df)

    hook = SnowflakeHook(snowflake_conn_id="raw")
    conn = hook.get_conn()
    cursor = conn.cursor()

    DB = conn.database
    SCHEMA = "PROCUREMENT"
    TABLE = "SCPRS_PURCHASES"

    # Create schema if not exists
    cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {DB}.{SCHEMA}")

    # Delete existing records in date range
    delete_sql = f"""
    DELETE FROM {DB}.{SCHEMA}.{TABLE}
    WHERE START_DATE >= '{start_date.strftime("%Y-%m-%d")}'
      AND START_DATE <= '{end_date.strftime("%Y-%m-%d")}'
    """
    try:
        cursor.execute(delete_sql)
        deleted_count = cursor.rowcount
        print(f"Deleted {deleted_count} existing records in date range")
    except Exception as e:
        # Table might not exist yet on first run
        print(f"Note: {e}")

    # Load new data
    write_pandas(
        conn,
        df,
        database=DB,
        schema=SCHEMA,
        table_name=TABLE,
        auto_create_table=True,
    )
    print(f"Inserted {len(df)} new records")

    # Clean up temp file
    if os.path.exists(file_path):
        os.remove(file_path)
        print(f"Cleaned up {file_path}")


def transform_lpa_data(df: pd.DataFrame) -> pd.DataFrame:
    """Transform scraped LPA data for Snowflake."""
    df = df.copy()

    # Parse dates: MM/DD/YYYY strings -> datetime, then convert to Python date objects
    # Note: Column names have two spaces (e.g., "Begin  Date")
    if "Begin  Date" in df.columns:
        df["Begin  Date"] = pd.to_datetime(
            df["Begin  Date"], format="%m/%d/%Y", errors="coerce"
        ).dt.date
    if "Expire  Date" in df.columns:
        df["Expire  Date"] = pd.to_datetime(
            df["Expire  Date"], format="%m/%d/%Y", errors="coerce"
        ).dt.date

    # Uppercase columns and replace whitespace with underscores for Snowflake convention
    df.columns = df.columns.str.upper().str.replace(r"\s+", "_", regex=True)

    # Add load timestamp
    df["LOADED_AT"] = datetime.now()

    return df


@task
def scrape_lpa() -> str:
    """Scrape all LPA contracts (both active and expired) and write to /tmp."""
    context = get_current_context()

    # Get expired contracts
    print("Fetching expired contracts...")
    scraper_expired = LPAScraper(debug=False)
    df_expired = scraper_expired.search(show_expired=True)
    df_expired["status"] = "expired"
    print(f"✓ Retrieved {len(df_expired)} expired contracts")

    # Get active contracts
    print("Fetching active contracts...")
    scraper_active = LPAScraper(debug=False)
    df_active = scraper_active.search(show_expired=False)
    df_active["status"] = "active"
    print(f"✓ Retrieved {len(df_active)} active contracts")

    # Combine
    df_all = pd.concat([df_expired, df_active], ignore_index=True)
    print(f"Total: {len(df_all)} contracts")
    print(f"  - Expired: {len(df_expired)}")
    print(f"  - Active:  {len(df_active)}")

    # Convert all object columns to strings to avoid mixed-type issues with Parquet
    for col in df_all.select_dtypes(include=["object"]).columns:
        df_all[col] = df_all[col].astype(str)

    # Write to /tmp and return file path
    file_path = f"/tmp/lpa_{context['dag_run'].run_id}.parquet"
    df_all.to_parquet(file_path, index=False)
    print(f"Wrote {len(df_all)} records to {file_path}")

    return file_path


@task
def load_lpa_to_snowflake(file_path: str) -> None:
    """Load LPA data to Snowflake with full replace strategy."""
    # Read dataframe from /tmp
    df = pd.read_parquet(file_path)
    print(f"Read {len(df)} records from {file_path}")

    # Transform data
    df = transform_lpa_data(df)

    hook = SnowflakeHook(snowflake_conn_id="raw")
    conn = hook.get_conn()
    cursor = conn.cursor()

    DB = conn.database
    SCHEMA = "PROCUREMENT"
    TABLE = "LPA_CONTRACTS"

    # Create schema if not exists
    cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {DB}.{SCHEMA}")

    # Load new data with overwrite=True (full replace)
    write_pandas(
        conn,
        df,
        database=DB,
        schema=SCHEMA,
        table_name=TABLE,
        auto_create_table=True,
        overwrite=True,
    )
    print(f"Loaded {len(df)} records (table overwritten)")

    # Clean up temp file
    if os.path.exists(file_path):
        os.remove(file_path)
        print(f"Cleaned up {file_path}")


@dag(
    description="Load IT procurement data from SCPRS and LPA contracts",
    schedule_interval="@monthly",
    start_date=datetime(2004, 1, 1),
    catchup=False,
    max_active_runs=2,  # Limit concurrency to avoid stressing PeopleSoft server
    default_args=DEFAULT_ARGS,
)
def scprs_procurement_data():
    """
    Scrapes IT procurement data and LPA contracts.

    SCPRS (IT Goods and IT Services):
    - Monthly: Runs on 1st of month, fetches previous 365 days
    - Backfill: Manual trigger with custom logical_date
    - Strategy: DELETE + INSERT for date range

    LPA Contracts (Active and Expired):
    - Monthly: Full snapshot of all contracts
    - Strategy: overwrite=True (full replace)

    Tasks are independent and run in parallel.
    """
    # SCPRS procurement tasks
    scprs_file = scrape_scprs()  # Scrapes both IT Goods and IT Services, writes to /tmp
    load_to_snowflake(scprs_file)  # Reads from /tmp, DELETE + INSERT for date range

    # LPA contract tasks (independent)
    lpa_file = (
        scrape_lpa()
    )  # Scrapes all active and expired LPA contracts, writes to /tmp
    load_lpa_to_snowflake(lpa_file)  # Reads from /tmp, overwrite=True


run = scprs_procurement_data()
