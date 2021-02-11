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

locals {
  instance_count = var.instance_count > 8 ? 8 : var.instance_count
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

# ------------------------------------------------------------------
# Resources to create
# ------------------------------------------------------------------

# Create Ubuntu server/s and install per setup instruction

data "template_file" "user_data" {
  vars = {
    gitlab_runner_registration_url   = var.gitlab_runner_registration_url
    gitlab_runner_registration_token = var.gitlab_runner_registration_token
  }

  template = <<-EOF
    #! /bin/bash

    # Install Docker
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker ubuntu

    # Download the binary for your system
    sudo curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64

    # Give it permissions to execute
    sudo chmod +x /usr/local/bin/gitlab-runner

    # Create a GitLab CI user
    sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash

    # Install and run as service
    sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
    sudo gitlab-runner start

    # Register the runner
    sudo gitlab-runner register --url $${gitlab_runner_registration_url} --registration-token $${gitlab_runner_registration_token}
    EOF
}

# Create AWS Instance for webhook server
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

  user_data = data.template_file.user_data.rendered

  tags = {
    Name  = format("tf-gitlab-runner-%d", count.index + 1)
    Owner = "QA Gitlab Runner (POC)"
  }
}
