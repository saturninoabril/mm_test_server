variable "mattermost_docker_image" {
  description = "Mattermost edition, e.g. mattermost-enterprise-edition, mm-ee-test, mm-cloud-ee"
  type        = string
}

variable "mattermost_docker_tag" {
  description = "Mattermost image tag, e.g. master, release-5.30, prod-d922f9d-10, 704_60b27ef5_9f16e221_d6b4d697"
  type        = string
}

variable "mm_env" {
  description = "Mattermost environment variables, comma (,) separated for multiple k/v pairs, e.g. MM_FEATUREFLAGS_GLOBALHEADER=true"
}

variable "edition" {
  description = "Mattermost edition, e.g. 'ce' for cloud, 'ee' for enterprise and 'te' for team"
  type        = string
  default     = "te"
}

variable "docker_username" {
  type = string
}

variable "docker_password" {
  type = string
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

variable "max_instance_count" {
  description = "Max number of instances to launch"
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

variable "route53_zone_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "state_bucket" {
  description = "S3 bucket for state"
  type        = string
}

variable "state_key" {
  description = "State key"
  type        = string
}

variable "lock_table" {
  description = "DynamoDB Table for state locks"
  type        = string
}

variable "use_num_suffix" {
  description = "Always append numerical suffix to instance name, even if instance_count is 1"
  type        = bool
  default     = true
}
