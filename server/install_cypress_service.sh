#! /bin/bash
sudo apt-get update

sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    git

# Install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Download docker files
export HOME=/home/ubuntu
cd $HOME
mkdir docker_build
cd docker_build
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker_build/cypress_docker_file --output $HOME/docker_build/cypress_docker_file
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker_build/webhook_docker_file --output $HOME/docker_build/webhook_docker_file

# Clone mattermost-webapp
cd $HOME
git clone https://github.com/mattermost/mattermost-webapp.git

# Build docker images
sudo docker build -f docker_build/cypress_docker_file -t saturnino/mm-e2e-cypress .
sudo docker build -f docker_build/webhook_docker_file -t saturnino/mm-e2e-webhook .

# RUn docker images
@echo --- Run Cypress using docker image
docker run -d --name mm-e2e-cypress-1 \
  -e CI_BASE_URL=master-e20-prod-ee-5.30.1-1.dev.spinmint.com \
  -e CYPRESS_baseUrl=http://master-e20-prod-ee-5.30.1-1.dev.spinmint.com \
  -e CYPRESS_dbConnection=postgres://mmuser:mostest@master-e20-prod-ee-5.30.1-1.dev.spinmint.com:5432/mattermost_test?sslmode=disable\u0026connect_timeout=10 \
  -e CYPRESS_webhookBaseUrl=http://master-e20-prod-ee-5.30.1-1.dev.spinmint.com:3000 \
  -e CYPRESS_smtpUrl=http://master-e20-prod-ee-5.30.1-1.dev.spinmint.com:10080 \
  -e CYPRESS_ciBaseUrl=master-e20-prod-ee-5.30.1-1.dev.spinmint.com \
  saturnino/mm-e2e-cypress:latest \
  node run_tests --stage='@prod' --part=1 --of=4

# docker run -d --name mm-e2e-cypress-2 --env-file="docker_build/cypress2.env" saturnino/mm-e2e-cypress:latest node run_tests --stage='@prod' --part=2 --of=4
# docker run -d --name mm-e2e-cypress-3 --env-file="docker_build/cypress3.env" saturnino/mm-e2e-cypress:latest node run_tests --stage='@prod' --part=3 --of=4
# docker run -d --name mm-e2e-cypress-4 --env-file="docker_build/cypress4.env" saturnino/mm-e2e-cypress:latest node run_tests --stage='@prod' --part=4 --of=4
docker update --restart unless-stopped $(docker ps -q)

# Check running container
sudo docker ps -a
