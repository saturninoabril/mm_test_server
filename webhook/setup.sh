#!/bin/sh

# Install terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform
terraform -help

export HOME=/home/ubuntu
cd $HOME
git clone https://github.com/saturninoabril/mm_test_server.git
cd mm_test_server/server
chmod +x terraform_create.sh
chmod +x terraform_destroy.sh
# Change values at ~/mm_test_server/server/main.tf
# Set required variables at ~/mm_test_server/server/terraform.tfvars
terraform init

# Download webhook
cd $HOME
curl -L https://github.com/adnanh/webhook/releases/download/2.7.0/webhook-linux-amd64.tar.gz --output webhook-linux-amd64.tar.gz
tar -xvzf webhook-linux-amd64.tar.gz

cd webhook-linux-amd64
cp $HOME/mm_test_server/webhook/hooks.json $HOME/webhook-linux-amd64/hooks.json

# Change values at ~/webhook-linux-amd64/hooks.json
# ./webhook -hooks hooks.json -verbose
