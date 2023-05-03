variable "locator" {
  description = "Snowflake account locator"
  type        = string
  default     = "heb41095"
}

variable "airflow_public_key" {
  description = "Public key for Airflow service user"
  type        = string
  default     = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArMGtTtTc+kxRirGFkf6LwlaOxxs1ZyodB0ZhOaNnDexGr5gkmcIv/5fcS5ZYAeLkIwMX+/V8RNBwSLYDfPWzAaZzxldCqQojA4b5RvYhryEor4jlE40WSyWB1gViTs0grqigAcQV5icS53BXIH9dlHR/wtM6U04vKDx9AzhJv2/x35Pc1NLm7RsdaWH9OvKnnySpA1TWoQ3zKFSy8LW79E4MF+mwLy9vwM92GtV4FJqnZeLE75W0QRKfM4kPTLWlDog4MJKw+RQwmNXZj9MrCHV+z9GLkQW3ba0+W8jM0AvPoA8xtJvQ/4g3gCVVfjOt5euQQU8AGkUAt4TTsbm1WwIDAQAB"
}

variable "dbt_public_key" {
  description = "Public key for dbt Cloud service user"
  type        = string
  default     = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxGn4yPVeOTBHFDCEf6idprUOLUyR12FICA8UAOtLzYDIqJdSHcQUhrHqqXtPn0Zp8YJbfSbUadNmP5van3F8Q0DcuY+SWOd0MeeSJYkoaib1YTARzLidVn3HSSiQofuSTw60lvc8POMH9Km9q2wLiVmOaGSSbgXBk3K22jb1J2QVoJeOT0awJRgZTAix9TOQEFiUmXZEBe23rPzP86yoERr0JCDlDYjB17S83FxF+gZdpv92Mjbi5s5SBXSPHwIPKUN6qOEAmL5fRheSD+J3TNPmZw8H6w4kYJlSxAQUflumhj7M7eeWwCqnB+OakaBxOVjbe3x80JaVZXPUTnFg0QIDAQAB"
}
