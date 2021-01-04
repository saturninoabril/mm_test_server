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
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker_build/Dockerfile.cypress --output $HOME/docker_build/Dockerfile.cypress
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker_build/Dockerfile.webhook --output $HOME/docker_build/Dockerfile.webhook

# Clone mattermost-webapp
cd $HOME
git clone https://github.com/mattermost/mattermost-webapp.git

# Build docker images
sudo docker build -f docker_build/Dockerfile.cypress -t saturnino/mm-e2e-cypress .
sudo docker build -f docker_build/Dockerfile.webhook -t saturnino/mm-e2e-webhook .

# RUn docker images
@echo --- Run Cypress using docker image
docker run -d --name mm-e2e-cypress-1 \
  -e CI_BASE_URL=<> \
  -e CYPRESS_baseUrl=http://<> \
  -e CYPRESS_dbConnection=postgres://<>/mattermost_test?sslmode=disable\u0026connect_timeout=10 \
  -e CYPRESS_webhookBaseUrl=http://<>:3000 \
  -e CYPRESS_smtpUrl=http://<>:10080 \
  -e CYPRESS_ciBaseUrl=<> \
  saturnino/mm-e2e-cypress:latest \
  node run_tests --stage='@prod' --part=1 --of=4

# docker run -d --name mm-e2e-cypress-2 --env-file="docker_build/cypress2.env" saturnino/mm-e2e-cypress:latest node run_tests --stage='@prod' --part=2 --of=4
# docker run -d --name mm-e2e-cypress-3 --env-file="docker_build/cypress3.env" saturnino/mm-e2e-cypress:latest node run_tests --stage='@prod' --part=3 --of=4
# docker run -d --name mm-e2e-cypress-4 --env-file="docker_build/cypress4.env" saturnino/mm-e2e-cypress:latest node run_tests --stage='@prod' --part=4 --of=4
docker update --restart unless-stopped $(docker ps -q)

# Check running container
sudo docker ps -a
