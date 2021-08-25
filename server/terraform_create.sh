#!/bin/sh

echo Workspace: $WORKSPACE
echo Edition: $EDITION
echo Docker Image: $DOCKER_IMAGE
echo Docker Tag: $DOCKER_TAG
echo Instance count: $INSTANCE_COUNT
echo Instance with MM env variables: $MM_ENV

terraform workspace select $WORKSPACE || terraform workspace new $WORKSPACE

echo "terraform workspace list:"
terraform workspace list

echo "terraform workspace show:"
terraform workspace show

echo "terraform apply --auto-approve:"
terraform apply \
  -var="edition=$EDITION" \
  -var="mattermost_docker_image=$DOCKER_IMAGE" \
  -var="mattermost_docker_tag=${DOCKER_TAG}" \
  -var="instance_count=$INSTANCE_COUNT" \
  -var="mm_env=$MM_ENV" \
  --auto-approve \
  -lock=false
