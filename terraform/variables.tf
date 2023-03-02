variable "name" {
  description = "Prefix of name to append resource"
  type        = string
  default     = "dse-infra-dev"
}

variable "region" {
  description = "Region for AWS resources"
  type        = string
  default     = "us-west-1"
}
