# Print outputs

output "aws_route53_record_id" {
  description = "Test Server Public Route53"
  value       = aws_route53_record.this.*.id
}

output "server_public_dns" {
  description = "Test Server Public DNS"
  value       = aws_instance.this.*.public_dns
}

output "server_public_ip" {
  description = "Test Server Public IP"
  value       = aws_instance.this.*.public_ip
}

output "common_server_public_dns" {
  description = "Common Server Public DNS"
  value       = aws_instance.common.*.public_dns
}

output "common_server_public_ip" {
  description = "Common Server Public IP"
  value       = aws_instance.common.*.public_ip
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "The ARN of the S3 bucket"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "The name of the DynamoDB table"
}
