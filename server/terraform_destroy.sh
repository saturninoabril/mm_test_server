#!/bin/sh

echo Edition: $WORKSPACE

terraform workspace select $WORKSPACE

echo "terraform workspace list:"
terraform workspace list

echo "terraform workspace show:"
terraform workspace show

echo "terraform destroy --auto-approve:"
terraform destroy --auto-approve -lock=false

echo "terraform delete workspace"
terraform workspace select default
terraform workspace delete $WORKSPACE
