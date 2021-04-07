variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "e20_license" {
  type = string
}

variable "mattermost_docker_image" {
  description = "Mattermost edition, e.g. mattermost-enterprise-edition, mm-ee-test, mm-cloud-ee"
  type        = string
}

variable "mattermost_docker_tag" {
  description = "Mattermost image tag, e.g. master, release-5.30, prod-d922f9d-10, 704_60b27ef5_9f16e221_d6b4d697"
  type        = string
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

variable "route53_zone_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}
