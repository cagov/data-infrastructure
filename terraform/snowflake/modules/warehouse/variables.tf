variable "name" {
  description = "Warehouse name"
  type        = string
}

variable "comment" {
  description = "Comment to apply to warehouse"
  type        = string
  default     = null
}

variable "auto_suspend" {
  description = "Auto-suspend time for warehouse"
  type        = number
  default     = 300
}

variable "size" {
  description = "Size of warehouse"
  type        = string
  default     = "x-small"
}
