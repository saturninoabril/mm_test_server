# Print outputs

output "aws_route53_record_id" {
  description = "Webhook Server Public Route53"
  value       = aws_route53_record.this.id
}

output "server_public_dns" {
  description = "Webhook Server Public DNS"
  value       = aws_instance.this.public_dns
}
