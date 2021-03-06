#!/bin/sh

echo Workspace: $WORKSPACE
echo Edition: $EDITION
echo Docker Image: $DOCKER_IMAGE
echo Docker Tag: $DOCKER_TAG
echo Instance count: $INSTANCE_COUNT
echo Instance with Keycloak: $WITH_KEYCLOAK
echo Instance with Elasticsearch: $WITH_ELASTICSEARCH

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
  -var="with_keycloak=$WITH_KEYCLOAK" \
  -var="with_elasticsearch=$WITH_ELASTICSEARCH" \
  --auto-approve \
  -lock=false
