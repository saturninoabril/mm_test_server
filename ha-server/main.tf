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

# Set Route53 record
data "aws_route53_zone" "selected" {
  name = format("%s.", var.route53_zone_name)
}

# ------------------------------------------------------------------
# Resources to create
# ------------------------------------------------------------------

# Create Ubuntu server and install per setup instruction

data "template_file" "user_data" {
  vars = {
    mattermost_docker_image = var.mattermost_docker_image
    mattermost_docker_tag   = var.mattermost_docker_tag
    license                 = var.e20_license
  }

  template = <<-EOF
    #! /bin/bash
    sudo apt-get update

    sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg-agent \
      software-properties-common

    # Install docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker ubuntu

    sudo docker run -d \
        --name db \
        -e POSTGRES_USER=mmuser \
        -e POSTGRES_PASSWORD=mostest \
        -e POSTGRES_DB=mattermost \
        mattermost/mattermost-prod-db

    sudo docker run -d \
        --name minio \
        -p 9000:9000 \
        -e MINIO_ACCESS_KEY=minioaccesskey \
        -e MINIO_SECRET_KEY=miniosecretkey \
        minio/minio \
        server /data

    sudo docker exec minio sh -c 'mkdir -p /data/mattermost-test'

    cd /tmp
    mkdir mm
    sudo chown -R 2000:2000 /tmp/mm
    sudo chown -R 2000:2000 /tmp/mm

    # copy server license
    cd /tmp/mm
    touch mattermost.mattermost-license
    echo $${license} > mattermost.mattermost-license

    # copy config.json to tmp/mm/config/config.json
    curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/ha-server/mattermost/config.json --output /tmp/mm/config.json

    sudo docker run -d \
        --link db \
        --link minio \
        -p 8065:8065 \
        -v /tmp/mm/config/config.json:/mattermost/config/config.json \
        -v /tmp/mm/:/tmp/ \
        --name app \
        mattermost/$${mattermost_docker_image}:$${mattermost_docker_tag}

    sudo docker run -d \
        --link db \
        --link minio \
        --link app \
        -p 8066:8065 \
        -v /tmp/mm/config/config.json:/mattermost/config/config.json \
        -v /tmp/mm/:/tmp/ \
        --name app1 \
        mattermost/$${mattermost_docker_image}:$${mattermost_docker_tag}

    # copy ha-mattermost to /tmp/nginx/nginx.conf
    curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/ha-server/nginx/nginx.conf --output /tmp/nginx/nginx.conf

    sudo docker run -d \
        -v /tmp/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
        --name mm-nginx \
        nginx

    EOF
}

# Create AWS Instance
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
    Name = format("ha-test-server-%s.${var.route53_zone_name}", terraform.workspace)
  }
}

# Create Route53 Record
resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = format("ha-test-server-%s.${var.route53_zone_name}", terraform.workspace)
  type    = "A"
  ttl     = "300"
  records = [aws_instance.this.public_ip]
}
