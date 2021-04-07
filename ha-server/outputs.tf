# Print outputs

output "aws_route53_record_id" {
  description = "HA Server Public Route53"
  value       = aws_route53_record.this.id
}

output "server_public_dns" {
  description = "HA Server Public DNS"
  value       = aws_instance.this.public_dns
}
