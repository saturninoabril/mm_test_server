# mm_test_server
A project that creates any number of test servers from a remote machine using Terraform and Webhook.

### mm_test_server/state
1. Create `terraform.tfvars and set required environment variables.
2. Verify that you can create and destroy server by `terraform apply` and `terraform destroy`, respectively.
3. Note of the S3 bucket and DynamoDB table to be used as remote backend for `mm_test_server/server`

### mm_test_server/server
1. Create `terraform.tfvars and set required environment variables.
2. Verify that you can create and destroy server by `terraform apply` and `terraform destroy`, respectively.

### mm_test_server/webhook
1. Create `terraform.tfvars and set required environment variables.

2. Initiate terraform
```
terraform apply --auto-approve
```

3. Take note of the output public DNS and access the machine directly.
  a. Set AWS profile, see https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html.
  b. Edit `~/webhook-linux-amd64/hooks.json`, and change names and values indicated by `"change"`. This can be a basic token that permits execution when name and value have exact match. Keep the values strongly unique and secret.
Note: This can be done via Terraform directly but ..., just do it manually.

4. Run the server by ``./webhook -hooks hooks.json``. It will be accessible via ``http://localhost:9000``.

5. To create server: ``POST https://[url]:9000/hooks/create?token=secretS&workspace=team``
