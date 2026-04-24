admin_user_email = "ian.rose@innovation.ca.gov"
allowed_ip_addresses = [
  # Jamf
  "52.35.167.128/32",
  "54.68.255.75/32",
  "54.186.76.74/32",
  "54.209.62.128/32",
  "52.200.243.25/32",
  "54.165.60.253/32",
  # MWAA
  "54.149.133.93/32",
  "54.148.133.98/32",
  # Fivetran GCP us-east-4 (default processing region)
  "35.234.176.144/29",
  # Snowflake egress IP ranges (expires 2026-06-14)
  # In a production setup we would automate cycling these
  # as they expire, but for the purposes of a POC this
  # seems okay.
  "153.45.59.0/24",
  "153.45.69.0/24",
  # Estuary IP ranges
  "34.213.10.188/32",
  "52.34.175.198/32",
  # Databricks NAT Gateway IP
  "48.221.48.2/32"
]
