{{ database(
  name=raw_name,
  comment='Raw database, intended for ingest of raw data from source systems prior to any modeling or transformation'
) }}

{{ database(
  name=transform_name,
  comment='Transformation database'
) }}

{{ database(
  name=analytics_name,
  comment='Analytics database for data consumers, holding analysis-ready data marts/models'
) }}
