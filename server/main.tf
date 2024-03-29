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
  instance_type  = "t3.medium"
  spot_price = lookup({
    "t3.medium" = "0.015",
    "t3.small"  = "0.009",
    "t3.micro"  = "0.005",
  }, local.instance_type, "0.005")

  license = lookup({
    "ce"                      = var.cloud_user,
    "ee"                      = var.e20_user,
    "mattermost-team-edition" = "",
  }, var.edition, "")

  url_base_prefix = substr(format("%s-%s-%s", terraform.workspace, var.edition, var.mattermost_docker_tag), 0, 45)
}

# ------------------------------------------------------------------
# Resources to create
# ------------------------------------------------------------------

# Create Ubuntu server/s and install per setup instruction

data "template_file" "init" {
  count    = local.instance_count
  template = file("init.tpl")

  vars = {
    app_instance_url        = format("%s-%d.%s", local.url_base_prefix, count.index + 1, var.route53_zone_name)
    mattermost_docker_image = var.mattermost_docker_image
    mattermost_docker_tag   = var.mattermost_docker_tag
    mm_env                  = var.mm_env
    license                 = local.license
    docker_username         = var.docker_username
    docker_password         = var.docker_password
  }
}

# Create AWS Instance for individual mm-app server
resource "aws_spot_instance_request" "this" {
  count = local.instance_count

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = local.instance_type
  spot_price           = local.spot_price
  spot_type            = "one-time"
  wait_for_fulfillment = true
  availability_zone    = var.availability_zone
  key_name             = var.key_name
  root_block_device {
    volume_size = 20
  }

  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [data.aws_security_group.selected.id]

  user_data = data.template_file.init[count.index].rendered

  tags = {
    Name  = var.instance_count > 1 || var.use_num_suffix ? format("%s-%d.%s", local.url_base_prefix, count.index + 1, var.route53_zone_name) : var.mattermost_docker_tag
    Owner = local.url_base_prefix
  }
}

resource "aws_route53_record" "this" {
  count = local.instance_count

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = format("%s-%d.%s", local.url_base_prefix, count.index + 1, var.route53_zone_name)
  type    = "A"
  ttl     = "300"
  records = [aws_spot_instance_request.this[count.index].public_ip]
}
