#!/usr/bin/env python3
"""
SCPRS Scraper using Excel download instead of pagination.

Tests the download approach before integrating into the Airflow DAG.
"""

import os
import re
import tempfile
import warnings
from typing import Optional

import pandas as pd
import requests
from bs4 import XMLParsedAsHTMLWarning

# Suppress XMLParsedAsHTMLWarning from BeautifulSoup
warnings.filterwarnings("ignore", category=XMLParsedAsHTMLWarning)


class SCPRSScraper:
    """HTTP-based scraper for SCPRS using Excel download."""

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
        form_data["ICBcDomData"] = "UnknownValue"
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
        """Perform a search on SCPRS and download results as Excel.

        Request sequence:
        1. GET: Initialize session (done in __init__)
        2. POST: Fill acquisition type field (if provided)
        3. POST: Execute search with other parameters
        4. POST: Click download button
        5. POST: Confirm download and receive Excel file

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
            f"Search parameters: dept={department}, acq_type={acquisition_type}, dates={start_date_from} to {start_date_to}"
        )

        try:
            # Step 1: Execute search
            response = self.session.post(url, data=form_data, timeout=180)
            response.raise_for_status()

            self._log(
                f"Search response: {response.status_code}, {len(response.text)} bytes"
            )

            # Extract updated ICStateNum from response
            self._extract_tokens_from_html(response.text)

            # Step 2: Download the Excel file
            tmp_path = self._download()

            # Step 3: Parse the HTML table (file is likely HTML formatted as Excel)
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
            import traceback

            traceback.print_exc()
            return pd.DataFrame()

    def _base_form_data(self, action: str) -> dict:
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

    def _build_form_data(
        self,
        department: Optional[str] = None,
        start_date_from: Optional[str] = None,
        start_date_to: Optional[str] = None,
    ) -> dict:
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

    def _download(self) -> str:
        """Download search results as Excel file (internal method).

        Returns:
            Path to downloaded temporary file

        Raises:
            Exception: If download request fails
        """
        url = f"{self.BASE_URL}{self.SEARCH_PAGE}"

        self._log(f"Using ICStateNum: {self.icstate_num}")

        # Step 1: Click download button (ICStateNum=3)
        form_data = self._base_form_data("ZZ_SCPRS_SP_WRK_BUTTONS_GB")

        self._log("Clicking download button...")
        response = self.session.post(url, data=form_data, timeout=60)
        response.raise_for_status()

        self._log(f"Download button response: {len(response.text)} bytes")

        # Extract updated ICStateNum
        self._extract_tokens_from_html(response.text)

        # Step 2: Confirm download (#ICOK) (ICStateNum=4)
        form_data = self._base_form_data("#ICOK")

        self._log("Confirming download...")
        response = self.session.post(url, data=form_data, timeout=60)
        response.raise_for_status()

        self._log(f"Confirm response: {len(response.text)} bytes")

        # Step 3: Extract download URL from response
        # Look for .xls URL in the XML response
        download_url = None
        xls_pattern = r'(https?://[^\s<>"\']+\.xls[^\s<>"\']*)'
        match = re.search(xls_pattern, response.text)
        if match:
            download_url = match.group(1)
            self._log(f"Found download URL: {download_url}")
        else:
            raise Exception("No .xls download URL found in response")

        # Step 4: Download the actual Excel file
        self._log("Downloading Excel file from URL...")
        file_response = self.session.get(download_url, timeout=60)
        file_response.raise_for_status()

        self._log(f"Downloaded {len(file_response.content)} bytes")

        # Step 5: Save to temporary file
        with tempfile.NamedTemporaryFile(
            mode="wb", suffix=".xls", delete=False
        ) as tmp_file:
            tmp_file.write(file_response.content)
            tmp_path = tmp_file.name

        self._log(f"Saved to {tmp_path}")
        return tmp_path


def main():
    """Test the SCPRS scraper with download approach."""
    print("=" * 70)
    print("SCPRS Scraper Test (Download Approach)")
    print("=" * 70)

    # Initialize scraper
    scraper = SCPRSScraper(debug=True)

    print("\n" + "=" * 70)
    print("Searching for IT Goods from 01/01/2025 to 02/01/2025")
    print("=" * 70)

    # Search with download
    df = scraper.search(
        acquisition_type="IT Goods",
        start_date_from="01/01/2025",
        start_date_to="02/01/2025",
    )

    if not df.empty:
        print(f"\n✓ Successfully retrieved {len(df)} records")
        print("\nColumn names:")
        for col in df.columns:
            print(f"  - {col}")

        print("\nFirst few records:")
        print(df.head())

        # Save to CSV for inspection
        output_file = "scprs_download_test.csv"
        df.to_csv(output_file, index=False)
        print(f"\n✓ Saved to {output_file}")
    else:
        print("\n✗ No results found or error occurred")


if __name__ == "__main__":
    main()
