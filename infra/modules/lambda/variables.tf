variable "function_name"      { type = string }
variable "stage"              { type = string }
variable "source_dir"         { type = string }
variable "target_bucket"      { type = string }
variable "target_bucket_arn"  { type = string }
variable "dynamodb_table"     { type = string }
variable "tags"               { type = map(string) }