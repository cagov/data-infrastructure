variable "name" {
  description = "Database name"
  type        = string
}

variable "comment" {
  description = "Comment to apply to warehouse"
  type        = string
  default     = null
}

variable "data_retention_time_in_days" {
  description = "Data retention time in days"
  type        = number
  default     = 7
}
