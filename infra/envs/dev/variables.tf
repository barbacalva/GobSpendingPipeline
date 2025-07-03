variable "stage" {
  description = "Name of the stage environment."
  type        = string
  default     = "dev"
}

variable "profile" {
  description = "Name of the profile used by AWS."
  type        = string
  default     = "barbacalva"
}