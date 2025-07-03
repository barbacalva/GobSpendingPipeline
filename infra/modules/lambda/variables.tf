variable "function_name"      { type = string }
variable "stage"              { type = string }
variable "target_bucket"      { type = string }
variable "target_bucket_arn"  { type = string }
variable "tags"               { type = map(string) }

variable "source_dir" {
  type        = string
  description = "Directory containing handler.py and its dependencies"
}