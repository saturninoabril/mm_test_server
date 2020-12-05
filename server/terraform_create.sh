#!/bin/sh

echo Edition: $WORKSPACE
echo Docker Image: $DOCKER_IMAGE
echo Docker Tag: $DOCKER_TAG
echo Instance count: $INSTANCE_COUNT

export TF_VAR_mattermost_docker_image=$DOCKER_IMAGE
export TF_VAR_mattermost_docker_tag=$DOCKER_TAG
export TF_VAR_instance_count=$INSTANCE_COUNT

terraform workspace select $WORKSPACE || terraform workspace new $WORKSPACE

echo "terraform workspace list:"
terraform workspace list

echo "terraform workspace show:"
terraform workspace show

echo "terraform apply --auto-approve:"
terraform apply --auto-approve
