#!/bin/sh

echo Workspace: $WORKSPACE
echo Docker Image: $DOCKER_IMAGE
echo Docker Tag: $DOCKER_TAG
echo Instance count: $INSTANCE_COUNT
echo Edition: $EDITION
echo Mattermost env variables: $MM_ENV
echo Cloud instance API Key: $MM_CLOUD_API_KEY
echo Cloud instance customer ID: $MM_CUSTOMER_ID
echo Cloud instance installation ID: $MM_CLOUD_INSTALLATION_ID

terraform workspace select $WORKSPACE || terraform workspace new $WORKSPACE

echo "terraform workspace show:"
terraform workspace show

echo "terraform apply --auto-approve:"
terraform apply \
  -var="mattermost_docker_image=$DOCKER_IMAGE" \
  -var="mattermost_docker_tag=${DOCKER_TAG}" \
  -var="instance_count=$INSTANCE_COUNT" \
  -var="edition=$EDITION" \
  -var="mm_env=$MM_ENV" \
  -var="cloud_api_key=$MM_CLOUD_API_KEY" \
  -var="cloud_customer_id=$MM_CUSTOMER_ID" \
  -var="cloud_installation_id=$MM_CLOUD_INSTALLATION_ID" \
  --auto-approve \
  -lock=false
