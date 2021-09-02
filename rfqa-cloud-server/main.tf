terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    # Replace this with your bucket name!
    bucket = "change"
    key    = "change"
    region = "change"
    # Replace this with your DynamoDB table name!
    dynamodb_table = "change"
    encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

# ------------------------------------------------------------------
# Data sources to get VPC, subnet, security group and AMI details
# ------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Subnet
data "aws_subnet" "selected" {
  id = var.subnet_id
}

# Security Group
data "aws_security_group" "selected" {
  id = var.security_group_id
}

# Set Route53 records
data "aws_route53_zone" "selected" {
  name = format("%s.", var.route53_zone_name)
}

locals {
  instance_count = var.instance_count > var.max_instance_count ? var.max_instance_count : var.instance_count

  license = lookup({
    "cloud-starter"      = var.cloud_starter,
    "cloud-professional" = var.cloud_professional,
    "cloud-enterprise"   = var.cloud_enterprise,
  }, var.edition, "cloud-enterprise")
}

# ------------------------------------------------------------------
# Resources to create
# ------------------------------------------------------------------

# Create Ubuntu server/s and install per setup instruction

data "template_file" "init" {
  count    = local.instance_count
  template = file("init.tpl")

  vars = {
    app_instance_url        = format("%s-%d.%s", terraform.workspace, count.index + 1, var.route53_zone_name)
    mattermost_docker_image = var.mattermost_docker_image
    mattermost_docker_tag   = var.mattermost_docker_tag
    license                 = local.license
    edition                 = var.edition
    cloud_customer_id       = var.cloud_customer_id
    cloud_api_key           = var.cloud_api_key
    cloud_installation_id   = var.cloud_installation_id
    cloud_cws_url           = var.cloud_cws_url
    cloud_cws_api_url       = var.cloud_cws_api_url
    docker_username         = var.docker_username
    docker_password         = var.docker_password
  }
}

# Create AWS Instance for individual mm-app server
resource "aws_instance" "this" {
  count = local.instance_count

  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  availability_zone = var.availability_zone
  key_name          = var.key_name
  root_block_device {
    volume_size = 20
  }

  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [data.aws_security_group.selected.id]

  user_data = data.template_file.init[count.index].rendered

  tags = {
    Name  = var.instance_count > 1 || var.use_num_suffix ? format("%s-%d.%s", terraform.workspace, count.index + 1, var.route53_zone_name) : var.mattermost_docker_tag
    Owner = terraform.workspace
  }
}

resource "aws_route53_record" "this" {
  count = local.instance_count

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = format("%s-%d.%s", terraform.workspace, count.index + 1, var.route53_zone_name)
  type    = "A"
  ttl     = "5"
  records = [aws_instance.this[count.index].public_ip]
}
