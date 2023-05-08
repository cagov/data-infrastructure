variable "environment" {
  description = "Environment suffix"
  type        = string
}

variable "airflow_public_key" {
  description = "Public key for Airflow service user"
  type        = string
}

variable "dbt_public_key" {
  description = "Public key for dbt Cloud service user"
  type        = string
}

variable "github_ci_public_key" {
  description = "Public key for GitHub CI service user"
  type        = string
}
