"""
LPA Scraper for California eProcure

Scrapes LPA (Leveraged Procurement Agreement) data from caleprocure.ca.gov
Downloads data as Excel file rather than paginating through results.
"""

import requests
import json
import re
import time
from typing import Dict, Optional
from urllib.parse import urljoin
import pandas as pd


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

    def _initialize_session(self):
        """Initialize session by loading the search page."""
        try:
            url = f"{self.BASE_URL}{self.SEARCH_ENDPOINT}"
            self._log(f"Initializing session: {url}")

            # First request - page load
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

    def search(
        self,
        contract_id: Optional[str] = None,
        description: Optional[str] = None,
        contract_type: Optional[str] = None,
        buyer_id: Optional[str] = None,
        supplier_id: Optional[str] = None,
        supplier_name: Optional[str] = None,
        show_expired: bool = False,
        begin_date: Optional[str] = None,  # Format: MM/DD/YYYY
        end_date: Optional[str] = None,  # Format: MM/DD/YYYY
    ) -> Dict:
        """Perform a search on the LPA system.

        Args:
            contract_id: Contract ID to search for
            description: Description keyword search
            contract_type: Contract type filter
            buyer_id: Buyer ID
            supplier_id: Supplier ID
            supplier_name: Supplier name
            show_expired: Include expired contracts
            begin_date: Contract begin date from (MM/DD/YYYY)
            end_date: Contract end date to (MM/DD/YYYY)

        Returns:
            Dict with response data
        """
        url = f"{self.BASE_URL}{self.SEARCH_ENDPOINT}"

        form_data = {
            "IF-TargetVerb": "POST",
            "IF-TargetContent": json.dumps(self.TARGET_CONTENT),
            "IF-Template": "/pages/LPASearch/lpa-search.aspx",
            "IF-IgnoreContent": "",
            "ICDoModal": "1",
            "sortAction": "",
            "ICType": "Panel",
            "ICElementNum": "0",
            "ICStateNum": self.icstate_num or "1",
            "ICAction": "ZZ_CTR_SRC2_WRK_SEARCH_BTN",
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
            "ZZ_CTR_SRC2_WRK_CNTRCT_ID": contract_id or "",
            "DESCR_1": description or "",
            "ZZ_CTR_SRC2_WRK_ZZ_CNTRCT_TYPE": contract_type or "",
            "ZZ_CTR_SRC2_WRK_BUYER_ID": buyer_id or "",
            "ZZ_CTR_SRC2_WRK_VENDOR_ID": supplier_id or "",
            "ZZ_CTR_SRC2_WRK_NAME1": supplier_name or "",
            "ZZ_CTR_SRC2_WRK_ZZ_ACQ_TYPE": "",
        }

        # Add expired contracts checkbox
        if show_expired:
            form_data["ZZ_CTR_SRC2_WRK_CHECKED"] = "Y"
            form_data["ZZ_CTR_SRC2_WRK_CHECKED$chk"] = "Y"

        # Add date filters if provided
        if begin_date:
            form_data["ZZ_CTR_SRC2_WRK_FROM_DT"] = begin_date
        if end_date:
            form_data["ZZ_CTR_SRC2_WRK_TO_DT"] = end_date

        try:
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
            result_count = 0
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

            return {"status": "success", "data": data}

        except requests.exceptions.RequestException as e:
            return {"status": "error", "error": str(e)}

    def download(self, state_num: Optional[int] = None) -> Dict:
        """Request Excel download of search results.

        Returns:
            Dict with download URL or error
        """
        url = f"{self.BASE_URL}{self.SEARCH_ENDPOINT}"

        # Use provided state_num or fallback to self.icstate_num or default to '3'
        state = str(state_num) if state_num is not None else (self.icstate_num or "3")
        self._log(f"Using ICStateNum: {state}")

        form_data = {
            "IF-TargetVerb": "POST",
            "IF-TargetContent": json.dumps(self.TARGET_CONTENT),
            "IF-Template": "/pages/LPASearch/lpa-search.aspx",
            "IF-IgnoreContent": "",
            "ICDoModal": "1",
            "sortAction": "",
            "ICType": "Panel",
            "ICElementNum": "0",
            "ICStateNum": state,
            "ICAction": "ZZ_CTR_SRC_VW$hexcel$0",  # Excel download action
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
            "ZZ_CTR_SRC_VW$hnewpers$0": "0|0|1|0|0|0|0#1|0|1|0|0|0|0#3|0|1|0|0|0|0#4|0|1|0|0|156|1#5|0|0|0|0|0|0#6|0|0|0|0|0|0#7|0|0|0|0|0|0#8|0|0|0|0|103|0#9|0|0|0|0|85|1#10|0|0|0|0|99|0#11|0|0|0|0|0|0#12|0|0|2|1|151|1#13|0|0|0|0|71|0#14|0|0|0|0|113|0#15|0|0|0|0|67|0#16|0|0|0|0|67|0#18|0|0|0|0|96|1#19|0|0|0|0|51|0#20|0|0|0|0|0|0#21|0|0|0|0|0|0#22|0|0|0|0|0|0#23|0|0|0|0|0|0#24|0|0|0|0|0|0#25|0|0|0|0|0|0#26|0|0|0|0|0|0#28|0|0|0|0|0|0#29|0|0|0|0|0|0#30|0|0|0|0|0|0#31|0|0|0|0|0|0#",
            "ZZ_CTR_SRC2_WRK_CNTRCT_ID": "",
            "DESCR_1": "",
            "ZZ_CTR_SRC2_WRK_ZZ_CNTRCT_TYPE": "",
            "ZZ_CTR_SRC2_WRK_BUYER_ID": "",
            "ZZ_CTR_SRC2_WRK_VENDOR_ID": "",
            "ZZ_CTR_SRC2_WRK_NAME1": "",
            "ZZ_CTR_SRC2_WRK_ZZ_ACQ_TYPE": "",
            "ZZ_CTR_SRC2_WRK_CHECKED": "Y",
            "ZZ_CTR_SRC2_WRK_CHECKED$chk": "Y",
        }

        try:
            self._log("Requesting Excel download...")
            response = self.session.post(url, data=form_data, timeout=60)
            response.raise_for_status()

            self._log(f"Download response: {len(response.text)} bytes")

            data = response.json()

            # Extract download URL from attachmentLink in CaptureResults
            download_url = None

            # Check CaptureResults -> attachmentWrapper -> Children -> attachmentLink
            if (
                "CaptureResults" in data
                and "attachmentWrapper" in data["CaptureResults"]
            ):
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
                                # Already absolute URL
                                self._log(f"Download URL: {download_url}")

            if download_url:
                return {"status": "success", "download_url": download_url}
            else:
                return {
                    "status": "error",
                    "error": "No download URL found in response",
                    "data": data,
                }

        except requests.exceptions.RequestException as e:
            return {"status": "error", "error": str(e)}

    def download_file(self, download_url: str, output_path: str) -> bool:
        """Download the Excel file from the provided URL.

        Args:
            download_url: URL to download from
            output_path: Path to save the file

        Returns:
            True if successful, False otherwise
        """
        try:
            self._log(f"Downloading file to {output_path}")
            response = self.session.get(download_url, timeout=60)
            response.raise_for_status()

            with open(output_path, "wb") as f:
                f.write(response.content)

            self._log(f"Downloaded {len(response.content)} bytes")
            return True

        except Exception as e:
            print(f"Error downloading file: {e}")
            return False

    def parse_excel(self, file_path: str) -> pd.DataFrame:
        """Parse the downloaded Excel file into a DataFrame.

        The file is actually HTML formatted as Excel, so we parse it as HTML.

        Args:
            file_path: Path to the Excel file

        Returns:
            DataFrame with LPA data
        """
        try:
            self._log(f"Parsing Excel file: {file_path}")
            # File is actually HTML, read as HTML table
            df_list = pd.read_html(file_path)
            if len(df_list) > 0:
                df = df_list[0]  # Get first table
                self._log(f"Parsed {len(df)} rows, {len(df.columns)} columns")
                return df
            else:
                print("No tables found in HTML file")
                return pd.DataFrame()

        except Exception as e:
            print(f"Error parsing file: {e}")
            return pd.DataFrame()


def main():
    """Test the LPA scraper."""
    print("=" * 60)
    print("LPA Scraper Test")
    print("=" * 60)

    # Initialize scraper
    scraper = LPAScraper(debug=True)

    print("\n" + "=" * 60)
    print("Step 1: Search for expired contracts (like user demo)")
    print("=" * 60)

    # Search for expired contracts with no other filters (like user's demo)
    search_result = scraper.search(show_expired=True)

    if search_result["status"] == "success":
        print("\n✓ Search successful")

        # Save search response for debugging
        with open("lpa_search_response.json", "w") as f:
            json.dump(search_result["data"], f, indent=2)
        print("  Saved search response to lpa_search_response.json")
    else:
        print(f"\n✗ Search failed: {search_result.get('error')}")
        return

    print("\n" + "=" * 60)
    print("Step 2: Request download")
    print("=" * 60)

    # Request download
    download_result = scraper.download()

    if download_result["status"] == "success":
        download_url = download_result["download_url"]
        print(f"\n✓ Download URL obtained: {download_url}")
    else:
        print(f"\n✗ Download failed: {download_result.get('error')}")
        return

    print("\n" + "=" * 60)
    print("Step 3: Download Excel file")
    print("=" * 60)

    # Download the file
    output_file = "lpa_expired_contracts.xls"
    if scraper.download_file(download_url, output_file):
        print(f"\n✓ File downloaded: {output_file}")
    else:
        print(f"\n✗ File download failed")
        return

    print("\n" + "=" * 60)
    print("Step 4: Parse Excel file")
    print("=" * 60)

    # Parse the Excel file
    df = scraper.parse_excel(output_file)

    if not df.empty:
        print(f"\n✓ Parsed {len(df)} LPA records")
        print("\nColumn names:")
        for col in df.columns:
            print(f"  - {col}")

        print("\nFirst few records:")
        print(df.head())
    else:
        print("\n✗ Failed to parse Excel file")


if __name__ == "__main__":
    main()
