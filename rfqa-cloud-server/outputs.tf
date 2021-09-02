output "server_aws_route53_record" {
  description = "Test Server Public Route53"
  value       = aws_route53_record.this.*.name
}

output "server_public_dns" {
  description = "Test Server Public DNS"
  value       = aws_instance.this.*.public_dns
}

output "server_public_ip" {
  description = "Test Server Public IP"
  value       = aws_instance.this.*.public_ip
}
