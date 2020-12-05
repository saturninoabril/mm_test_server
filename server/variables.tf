variable "mattermost_docker_image" {
  description = "Mattermost edition, e.g. enterprise, mm-cloud-ee"
  type        = string
}

variable "mattermost_docker_tag" {
  description = "Mattermost image tag, e.g. master, release-5.30, prod-d922f9d-10"
  type        = string
  default     = "latest"
}

variable "cloud_user" {
  type = string
}

variable "e20_user" {
  type = string
}

variable "instance_count" {
  description = "Number of instances to launch"
  type        = number
  default     = 1
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

variable "mm_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "common_instance_type" {
  type    = string
  default = "t3.small"
}

variable "route53_zone_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "use_num_suffix" {
  description = "Always append numerical suffix to instance name, even if instance_count is 1"
  type        = bool
  default     = true
}
