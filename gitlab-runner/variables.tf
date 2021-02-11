variable "instance_count" {
  description = "Number of instances to launch"
  type        = number
  default     = 1
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "availability_zone" {
  type    = string
  default = "us-east-1a"
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "gitlab_runner_registration_url" {
  type = string
}

variable "gitlab_runner_registration_token" {
  type = string
}
