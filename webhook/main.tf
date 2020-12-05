terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
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

# ------------------------------------------------------------------
# Resources to create
# ------------------------------------------------------------------

# Create Ubuntu server/s and install per setup instruction

data "template_file" "user_data" {
  template = <<-EOF
    #! /bin/bash
    sudo apt-get update

    sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg-agent \
      software-properties-common

    # Download webhook
    curl https://github.com/adnanh/webhook/releases/download/2.7.0/webhook-linux-amd64.tar.gz --output webhook-linux-amd64.tar.gz
    tar -C ~/ -xzf webhook-linux-amd64.tar.gz

    curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/webhook/hooks.json --output $PWD/hooks.json

    ./webhook -hooks hooks.json -verbose

    until curl --max-time 5 --output - http://localhost:9000; do echo waiting for app; sleep 5; done;
    EOF
}

# Create AWS Instance for webhook server
resource "aws_instance" "this" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  availability_zone = var.availability_zone
  key_name          = var.key_name
  root_block_device {
    volume_size = 20
  }

  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [data.aws_security_group.selected.id]

  user_data = data.template_file.user_data.rendered

  tags = {
    Name = format("webhook-test-server-%s.${var.route53_zone_name}", terraform.workspace)
  }
}

# Create Route53 Records for individual app server
resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = format("webhook-test-server-%s.${var.route53_zone_name}", terraform.workspace)
  type    = "A"
  ttl     = "300"
  records = [aws_instance.this.public_ip]
}
