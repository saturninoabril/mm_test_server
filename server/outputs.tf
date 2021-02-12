# Print outputs

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

output "common_aws_route53_record" {
  description = "Common Public Route53"
  value       = aws_route53_record.common.*.name
}

output "common_server_public_dns" {
  description = "Common Server Public DNS"
  value       = aws_instance.common.*.public_dns
}

output "common_server_public_ip" {
  description = "Common Server Public IP"
  value       = aws_instance.common.*.public_ip
}

# output "cypress_server_public_dns" {
#   description = "Cypress Public DNS"
#   value       = aws_instance.cypress.public_dns
# }

# output "cypress_server_public_ip" {
#   description = "Cypress Public IP"
#   value       = aws_instance.cypress.public_ip
# }
