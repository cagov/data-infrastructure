"""
SCPRS Scraper - California State Procurement System

Scrapes procurement data using working server-side filters:
- Department
- Acquisition type
- Date range

Note: LPA Contract ID filtering does NOT work server-side.
Use client-side filtering for LPA IDs.
"""

import requests
import re
import argparse
import sys
import pandas as pd
import warnings
from typing import Dict, Optional, List
from bs4 import BeautifulSoup
from bs4 import XMLParsedAsHTMLWarning

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


def main():
    """CLI for SCPRS scraper."""
    parser = argparse.ArgumentParser(
        description="Search California SCPRS procurement data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Search by department and acquisition type
  python scprs_scraper.py --department 3540 --acquisition-type "IT Goods" \\
                          --start-date-from 10/01/2025 --start-date-to 11/01/2025

  # Export to CSV (automatically fetches all pages)
  python scprs_scraper.py --department 3540 --output results.csv

  # Show detailed output
  python scprs_scraper.py --department 3540 --verbose

  # Search with date range only
  python scprs_scraper.py --start-date-from 01/01/2025 --start-date-to 01/31/2025
        """,
    )

    parser.add_argument(
        "--department", help="Department code (e.g., 3540 for CAL FIRE)"
    )
    parser.add_argument(
        "--acquisition-type", help='Acquisition type (e.g., "IT Goods")'
    )
    parser.add_argument("--start-date-from", help="Start date from (MM/DD/YYYY)")
    parser.add_argument("--start-date-to", help="Start date to (MM/DD/YYYY)")
    parser.add_argument("--output", "-o", help="Output CSV file path")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Show detailed record information"
    )

    args = parser.parse_args()

    # Check if any search parameters provided
    if not any(
        [
            args.department,
            args.acquisition_type,
            args.start_date_from,
            args.start_date_to,
        ]
    ):
        parser.error("At least one search parameter is required")

    print("=" * 70)
    print("SCPRS Scraper")
    print("=" * 70)

    # Search and get results
    scraper = SCPRSScraper(debug=args.debug)
    df = scraper.search(
        department=args.department,
        acquisition_type=args.acquisition_type,
        start_date_from=args.start_date_from,
        start_date_to=args.start_date_to,
    )

    print(f"\n✓ Found {len(df)} records")

    # Show verbose output
    if args.verbose and len(df) > 0:
        print("\nFirst record:")
        r = df.iloc[0]
        print(f"  Purchase Doc: {r.get('purchase_doc')}")
        print(f"  Department: {r.get('department')}")
        print(f"  Supplier: {r.get('supplier_name')}")
        print(f"  Start Date: {r.get('start_date')}")
        print(f"  Total: {r.get('grand_total')}")
        print(f"  Acquisition Type: {r.get('acquisition_type')}")
        print(f"  Acquisition Method: {r.get('acquisition_method')}")
        print(f"  Status: {r.get('status')}")
        print(f"  Buyer: {r.get('buyer_name')}")
        print(f"  Buyer Email: {r.get('buyer_email')}")
        if r.get("certification_type"):
            print(f"  Certification: {r.get('certification_type')}")
        if r.get("lpa_contract_id"):
            print(f"  LPA Contract ID: {r.get('lpa_contract_id')}")

    # Export to CSV if requested
    if args.output:
        df.to_csv(args.output, index=False)
        print(f"\n✓ Saved to {args.output}")
    elif not args.verbose and len(df) > 0:
        # Show summary if not verbose and not saving
        print("\nSummary:")
        print(f"  Total amount: {df['grand_total'].count()} records with amounts")
        if "supplier_name" in df.columns:
            print(f"  Unique suppliers: {df['supplier_name'].nunique()}")
        if "department" in df.columns:
            print(f"  Unique departments: {df['department'].nunique()}")


if __name__ == "__main__":
    main()
