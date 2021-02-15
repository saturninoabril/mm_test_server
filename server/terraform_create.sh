#!/bin/sh

echo Edition: $WORKSPACE
echo Docker Image: $DOCKER_IMAGE
echo Docker Tag: $DOCKER_TAG
echo Instance count: $INSTANCE_COUNT
echo Enable Elasticsearch: $ENABLE_ELASTICSEARCH

terraform workspace select $WORKSPACE || terraform workspace new $WORKSPACE

echo "terraform workspace list:"
terraform workspace list

echo "terraform workspace show:"
terraform workspace show

echo "terraform apply --auto-approve:"
terraform apply \
  -var="mattermost_docker_image=$DOCKER_IMAGE" \
  -var="mattermost_docker_tag=$DOCKER_TAG" \
  -var="instance_count=$INSTANCE_COUNT" \
  -var="elasticsearch_instance=$ENABLE_ELASTICSEARCH" \
  --auto-approve \
  -lock=false
