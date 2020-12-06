variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  description = "S3 bucket for state"
  type        = string
}

variable "lock_table" {
  description = "DynamoDB Table for state locks"
  type        = string
}