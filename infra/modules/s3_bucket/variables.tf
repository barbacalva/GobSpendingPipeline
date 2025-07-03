variable "name" {
  description = "Name of the bucket"
  type        = string
}

variable "tags" {
  description = "Bucket tags"
  type        = map(string)
  default     = {}
}

variable "enable_versioning" {
  description = "Enables versioning (true/false)"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enables SSE-S3 encryption"
  type        = bool
  default     = true
}

variable "expire_after_days" {
  description = "Days after which objects expire (null = never)"
  type        = number
  default     = null
}