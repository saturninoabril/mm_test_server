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
    "mm-cloud-ee"                   = var.cloud_user,
    "mm-ee-test"                    = var.cloud_user,
    "mattermost-enterprise-edition" = var.e20_user,
    "mattermost-team-edition"       = "",
  }, var.mattermost_docker_image, "")

  edition = lookup({
    "mm-cloud-ee"                   = "ce",
    "mm-ee-test"                    = "ce",
    "mattermost-enterprise-edition" = "ee",
    "mattermost-team-edition"       = "te",
  }, var.mattermost_docker_image, "")

  url_base_prefix = substr(format("%s-%s-%s", terraform.workspace, local.edition, var.mattermost_docker_tag), 0, 45)
}

# ------------------------------------------------------------------
# Resources to create
# ------------------------------------------------------------------

# Create Ubuntu server/s and install per setup instruction

data "template_file" "user_data" {
  count = local.instance_count

  vars = {
    app_instance_url        = format("%s-%d.%s", local.url_base_prefix, count.index + 1, var.route53_zone_name)
    mattermost_docker_image = var.mattermost_docker_image
    mattermost_docker_tag   = var.mattermost_docker_tag
    license                 = local.license
    common_server_url       = var.elasticsearch_instance == 1 ? aws_instance.common[0].public_dns : "localhost"
    elasticsearch_instance  = var.elasticsearch_instance == 1 ? "true" : "false"
  }

  template = <<-EOF
    #! /bin/bash
    sudo apt-get update

    sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg-agent \
      software-properties-common \
      moreutils \
      jq

    export HOME=/home/ubuntu

    # Install docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker ubuntu

    # Set DB config
    export MM_SQLSETTINGS_DRIVERNAME="postgres"
    export MM_SQLSETTINGS_DATASOURCE="postgres://mmuser:mostest@mm-db:5432/mattermost_test?sslmode=disable&connect_timeout=10"

    # Check Elasticsearch
    if [$${elasticsearch_instance} -eq "true"]; then \
      until curl --max-time 5 --output - http://$${common_server_url}:9200; do echo waiting for elasticsearch; sleep 5; done;
    fi

    cd ~/
    mkdir docker-compose
    curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker-compose/docker-compose.yml --output ~/docker-compose/docker-compose.yml
    curl https://github.com/saturninoabril/mm_test_server/blob/main/server/docker-compose/docker-compose.common.yml --output ~/docker-compose/docker-compose.common.yml
    cd docker-compose && mkdir docker
    curl https://github.com/saturninoabril/mm_test_server/blob/main/server/docker-compose/docker/postgres.conf --output ~/docker-compose/docker/postgres.conf
    curl https://github.com/saturninoabril/mm_test_server/blob/main/server/docker-compose/docker/test-data.ldif --output ~/docker-compose/docker/test-data.ldif
    cd docker && mkdir keycloak
    curl https://github.com/saturninoabril/mm_test_server/blob/main/server/docker-compose/docker/keycloak/realm.json --output ~/docker-compose/docker/keycloak/realm.json

    # Run PostgreSQL DB
    sudo docker run -d \
      --name mm-db \
      -p 5432:5432 \
      -e POSTGRES_USER=mmuser \
      -e POSTGRES_PASSWORD=mostest \
      -e POSTGRES_DB=mattermost_test \
      -v "$HOME/docker-compose/docker/postgres.conf":/etc/postgresql/postgresql.conf \
      postgres:10

    sudo docker run -d \
      --name mm-inbucket \
      -p 10025:10025 \
      -p 10080:10080 \
      -p 10110:10110 \
      jhillyerd/inbucket:release-1.2.0

    sudo docker run -d \
      --name mm-openldap \
      -p 389:389 \
      -p 636:636 \
      -e LDAP_TLS_VERIFY_CLIENT="never" \
      -e LDAP_ORGANISATION="Mattermost Test" \
      -e LDAP_DOMAIN="mm.test.com" \
      -e LDAP_ADMIN_PASSWORD="mostest" \
      osixia/openldap:1.4.0

    cd ~/
    mkdir mattermost_config
    mkdir mattermost_data
    curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/mattermost/config.json --output ~/mattermost_config/config.json

    echo "Modify config"
    jq '.ElasticsearchSettings.ConnectionUrl = "http://$${common_server_url}:9200"' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
    jq '.ElasticsearchSettings.EnableIndexing = $${elasticsearch_instance}' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
    jq '.ElasticsearchSettings.EnableSearching = $${elasticsearch_instance}' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
    jq '.ElasticsearchSettings.EnableAutocomplete = $${elasticsearch_instance}' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
    jq '.ElasticsearchSettings.Sniff = false' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
    jq '.ServiceSettings.ListenAddress = ":8065"' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
    jq '.ServiceSettings.SiteURL = "http://$${app_instance_url}:8065"' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
    jq '.TeamSettings.MaxUsersPerTeam = 2000' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
    sleep 5

    sudo chown -R 2000:2000 ~/mattermost_config/
    sudo chown -R 2000:2000 ~/mattermost_data/

    cd ~/mattermost_config
    touch mattermost.mattermost-license
    echo $${license} > mattermost.mattermost-license

    # Run Mattermost mm-app
    sudo docker run -d \
      --name mm-app \
      --link mm-db \
      --link mm-openldap \
      --link mm-inbucket \
      -p 8065:8065 \
      -e MM_CLUSTERSETTINGS_READONLYCONFIG=false \
      -e MM_EMAILSETTINGS_SMTPSERVER=mm-inbucket \
      -e MM_LDAPSETTINGS_LDAPSERVER=mm-openldap \
      -e MM_PLUGINSETTINGS_ENABLEUPLOADS=true \
      -e MM_SQLSETTINGS_DRIVERNAME=$MM_SQLSETTINGS_DRIVERNAME \
      -e MM_SQLSETTINGS_DATASOURCE=$MM_SQLSETTINGS_DATASOURCE \
      -v $HOME/mattermost_config:/mattermost/config \
      -v $HOME/mattermost_data:/mattermost/data \
      mattermost/$${mattermost_docker_image}:$${mattermost_docker_tag}

    # Run MinIO object storage
    sudo docker run -d \
      --name mm-minio \
      -p 9000:9000 \
      -e MINIO_ACCESS_KEY=minioaccesskey \
      -e MINIO_SECRET_KEY=miniosecretkey \
      -e MINIO_SSE_MASTER_KEY="my-minio-key:6368616e676520746869732070617373776f726420746f206120736563726574" \
      minio/minio:RELEASE.2019-10-11T00-38-09Z server /data

    # Run webhook for UI testing
    sudo docker run -d \
      --name mm-e2e-webhook \
      --link mm-app \
      -p 3000:3000 \
      -e WEBHOOK_URL=http://mm-e2e-webhook:3000 \
      -e SITE_URL=http://mm-app:8065 \
      saturnino/mm-e2e-webhook:latest

    sudo docker exec mm-app sh -c 'mattermost sampledata -w 4 -u 60'
    # sudo docker restart mm-app
    sleep 10

    echo "Show config after restart"
    sudo docker exec mm-app sh -c 'mattermost config show'

    docker exec mm-openldap bash -c 'echo -e "dn: ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: organizationalunit" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=test.one,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Test1\nmail: success+testone@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=test.two,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Test2\nmail: success+testtwo@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=test.three,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Test3\nmail: success+testthree@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=test.four,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Test4\nmail: success+testfour@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=test.five,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Test5\nmail: success+testfive@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=dev-ops.one,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Dev3\nmail: success+devopsone@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=dev.one,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Dev1\nmail: success+devone@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=dev.two,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Dev2\nmail: success+devtwo@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=dev.three,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Dev3\nmail: success+devthree@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=dev.four,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Dev4\nmail: success+devfour@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=exec.one,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Exec1\nmail: success+execone@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=exec.two,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Exec2\nmail: success+exectwo@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=board.one,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Board1\nmail: success+boardone@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=board.two,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Board2\nmail: success+boardtwo@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: uid=board.three,ou=testusers,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: iNetOrgPerson\nsn: User\ncn: Board3\nmail: success+boardthree@simulator.amazonses.com\nuserPassword: Password1" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: organizationalunit" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=outsiders,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfNames\nmember: uid=board.three,ou=testusers,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=board,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfNames\nmember: uid=board.one,ou=testusers,dc=mm,dc=test,dc=com\nmember: uid=board.two,ou=testusers,dc=mm,dc=test,dc=com\nmember: cn=outsiders,ou=testgroups,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=executive,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfNames\nmember: uid=exec.one,ou=testusers,dc=mm,dc=test,dc=com\nmember: uid=exec.two,ou=testusers,dc=mm,dc=test,dc=com\nmember: cn=board,ou=testgroups,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=tgroup-84,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfNames\nmember: cn=tgroup-9,ou=testgroups,dc=mm,dc=test,dc=com\nmember: uid=test.five,ou=testusers,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=tgroup-9,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfNames\nmember: cn=tgroup-97,ou=testgroups,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=tgroup-97,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfNames\nmember: uid=test.four,ou=testusers,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=tgroup,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfUniqueNames\nuniqueMember: uid=test.one,ou=testusers,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=ugroup,cn=tgroup,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfUniqueNames\nuniqueMember: uid=test.two,ou=testusers,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=vgroup,cn=tgroup,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfUniqueNames\nuniqueMember: uid=test.three,ou=testusers,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=team-one-a,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfUniqueNames\nuniqueMember: uid=dev.four,ou=testusers,dc=mm,dc=test,dc=com\nuniqueMember: cn=developers,ou=testgroups,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=team-one,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfUniqueNames\nuniqueMember: uid=dev.one,ou=testusers,dc=mm,dc=test,dc=com\nuniqueMember: uid=dev.three,ou=testusers,dc=mm,dc=test,dc=com\nuniqueMember: cn=team-one-a,ou=testgroups,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=team-two,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfUniqueNames\nuniqueMember: uid=dev.two,ou=testusers,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    docker exec mm-openldap bash -c 'echo -e "dn: cn=developers,ou=testgroups,dc=mm,dc=test,dc=com\nchangetype: add\nobjectclass: groupOfUniqueNames\nuniqueMember: uid=dev-ops.one,ou=testusers,dc=mm,dc=test,dc=com\nuniqueMember: cn=team-one,ou=testgroups,dc=mm,dc=test,dc=com\nuniqueMember: cn=team-two,ou=testgroups,dc=mm,dc=test,dc=com" | ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest'

    sudo docker restart mm-app
    sleep 10
    until curl --max-time 5 --output - http://localhost:8065; do echo waiting for mm-app; sleep 5; done;
    EOF
}

# Create Route53 Records for common service
resource "aws_route53_record" "common" {
  count = var.elasticsearch_instance

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = format("%s-common.%s", local.url_base_prefix, var.route53_zone_name)
  type    = "A"
  ttl     = "300"
  records = [aws_instance.common[count.index].public_ip]
}

# Create AWS Instance for common server
resource "aws_instance" "common" {
  count = var.elasticsearch_instance

  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.common_instance_type
  availability_zone = var.availability_zone
  key_name          = var.key_name
  root_block_device {
    volume_size = 20
  }

  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [data.aws_security_group.selected.id]

  user_data = file("install_common_service.sh")

  tags = {
    Name  = format("common.%s", local.url_base_prefix)
    Owner = local.url_base_prefix
  }
}

# resource "aws_instance" "cypress" {
#   ami               = data.aws_ami.ubuntu.id
#   instance_type     = var.cypress_instance_type
#   availability_zone = var.availability_zone
#   key_name          = var.key_name
#   root_block_device {
#     volume_size = 30
#   }

#   subnet_id              = data.aws_subnet.selected.id
#   vpc_security_group_ids = [data.aws_security_group.selected.id]

#   user_data = file("install_cypress_service.sh")

#   tags = {
#     Name = format("%s-%s-common.${var.route53_zone_name}", var.mattermost_docker_tag, terraform.workspace)
#   }
# }

# Create Route53 Records for individual mm-app server
resource "aws_route53_record" "this" {
  count = local.instance_count

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = format("%s-%d.%s", local.url_base_prefix, count.index + 1, var.route53_zone_name)
  type    = "A"
  ttl     = "300"
  records = [aws_instance.this[count.index].public_ip]
}

# Create AWS Instance for individual mm-app server
resource "aws_instance" "this" {
  count = local.instance_count

  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.mm_instance_type
  availability_zone = var.availability_zone
  key_name          = var.key_name
  root_block_device {
    volume_size = 20
  }

  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [data.aws_security_group.selected.id]

  user_data = data.template_file.user_data[count.index].rendered

  tags = {
    Name  = var.instance_count > 1 || var.use_num_suffix ? format("%s-%d.%s", local.url_base_prefix, count.index + 1, var.route53_zone_name) : var.mattermost_docker_tag
    Owner = local.url_base_prefix
  }
}
