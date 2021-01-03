# Print outputs

output "aws_route53_record_name" {
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

output "acme_certificate_private_key_pem" {
  description = "ACME Cert Private Key Pem"
  value       = acme_certificate.certificate.*.private_key_pem
}

output "acme_certificate_pem" {
  description = "ACME Cert Pem"
  value       = acme_certificate.certificate.*.certificate_pem
}

output "acme_certificate_issuer_pem" {
  description = "ACME Cert Issuer Pem"
  value       = acme_certificate.certificate.*.issuer_pem
}

# output "acme_certificate_full_chain" {
#   description = "ACME Cert Full Chain"
#   value       = join("", [acme_certificate.certificate.*.certificate_pem, acme_certificate.certificate.*.issuer_pem])
# }

output "acme_certificate_url" {
  description = "ACME Cert URL"
  value       = acme_certificate.certificate.*.certificate_url
}

output "acme_certificate_domain" {
  description = "ACME Cert Domain"
  value       = acme_certificate.certificate.*.certificate_domain
}
