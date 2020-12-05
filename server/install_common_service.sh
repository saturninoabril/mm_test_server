#! /bin/bash
sudo apt-get update

sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

# Install nginx
sudo apt-get install -y nginx
sudo systemctl status nginx

# Install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Run Elasticsearch
sudo docker run -d \
    --name mm-elasticsearch \
    -p 9200:9200 \
    -e http.host="0.0.0.0" \
    -e http.port=9200 \
    -e http.cors.enabled="true" \
    -e http.cors.allow-origin="http://localhost:1358,http://127.0.0.1:1358" \
    -e http.cors.allow-headers="X-Requested-With,X-Auth-Token,Content-Type,Content-Length,Authorization" \
    -e http.cors.allow-credentials="true" \
    -e transport.host="127.0.0.1" \
    -e ES_JAVA_OPTS="-Xmx1024m -Xms1024m" \
    mattermost/mattermost-elasticsearch-docker:6.5.1

# Check running container
sudo docker ps -a

until curl --max-time 5 --output - http://localhost:9200; do echo waiting for app; sleep 5; done;
