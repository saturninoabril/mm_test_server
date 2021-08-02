variable "mattermost_docker_image" {
  description = "Mattermost docker image, e.g. mm-ee-test, mm-ee-cloud"
  type        = string
  default     = "mm-ee-test"
}

variable "mattermost_docker_tag" {
  description = "Mattermost docker image tag, e.g. 4481_296076bf_742d725e_b3f2bc2a, test, cloud-2021-07-29-1"
  type        = string
  default     = "test"
}

variable "edition" {
  description = "Mattermost edition, e.g. cloud-enterprise, cloud-professional or cloud-starter"
  type        = string
  default     = "cloud-enterprise"
}

variable "cloud_customer_id" {
  description = "Customer ID in CWS"
  type        = string
}

variable "cloud_api_key" {
  description = "API key in CWS"
  type        = string
}

variable "cloud_installation_id" {
  description = "Cloud installation ID in CWS"
  type        = string
}

variable "cloud_cws_url" {
  type = string
}

variable "cloud_cws_api_url" {
  type = string
}

variable "cloud_starter" {
  type = string
}

variable "cloud_professional" {
  type = string
}

variable "cloud_enterprise" {
  type = string
}

variable "docker_username" {
  type = string
}

variable "docker_password" {
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

variable "instance_type" {
  description = "Instance type to launch"
  type = string
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
