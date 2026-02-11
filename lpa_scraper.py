"""
LPA Scraper for California eProcure

Scrapes LPA (Leveraged Procurement Agreement) data from caleprocure.ca.gov
Downloads data as Excel file rather than paginating through results.

Usage:
    from lpa_scraper import LPAScraper

    # Initialize scraper
    scraper = LPAScraper()

    # Search for all expired contracts - returns DataFrame
    df = scraper.search(show_expired=True)

    # Search for active contracts
    df = scraper.search(show_expired=False)
"""

import json
import os
import re
import tempfile
import time
from urllib.parse import urljoin

import pandas as pd
import requests


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


def main():
    """Download all LPA contracts (both expired and active)."""
    print("=" * 70)
    print("Downloading All LPA Contracts")
    print("=" * 70)

    # Get expired contracts
    print("\nFetching expired contracts...")
    scraper_expired = LPAScraper(debug=False)
    df_expired = scraper_expired.search(show_expired=True)
    df_expired["status"] = "expired"
    print(f"✓ Retrieved {len(df_expired)} expired contracts")

    # Get active contracts
    print("\nFetching active contracts...")
    scraper_active = LPAScraper(debug=False)
    df_active = scraper_active.search(show_expired=False)
    df_active["status"] = "active"
    print(f"✓ Retrieved {len(df_active)} active contracts")

    # Combine
    df_all = pd.concat([df_expired, df_active], ignore_index=True)
    print(f"\n{'=' * 70}")
    print(f"Total: {len(df_all)} contracts")
    print(f"  - Expired: {len(df_expired)}")
    print(f"  - Active:  {len(df_active)}")

    # Save to CSV
    output_file = "lpa_all_contracts.csv"
    df_all.to_csv(output_file, index=False)
    print(f"\n✓ Saved to {output_file}")

    # Show sample
    print("\nSample records:")
    print(df_all.head())

    # Show breakdown by status
    print("\nBreakdown by status:")
    print(df_all["status"].value_counts())


if __name__ == "__main__":
    main()
