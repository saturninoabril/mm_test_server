# Print outputs

output "server_aws_route53_record" {
  description = "Test Server Public Route53"
  value       = aws_route53_record.this.*.name
}

output "server_public_dns" {
  description = "Test Server Public DNS"
  value       = aws_spot_instance_request.this.*.public_dns
}

output "server_public_ip" {
  description = "Test Server Public IP"
  value       = aws_spot_instance_request.this.*.public_ip
}
