output "public_subnet_ids" {
  description = "Public subnet IDs, ordered by the input CIDR list."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, ordered by the input CIDR list."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "public_subnet_cidr_blocks" {
  description = "Public subnet CIDR blocks."
  value       = [for subnet in aws_subnet.public : subnet.cidr_block]
}

output "private_subnet_cidr_blocks" {
  description = "Private subnet CIDR blocks."
  value       = [for subnet in aws_subnet.private : subnet.cidr_block]
}

output "public_subnet_ids_by_az" {
  description = "Public subnet IDs keyed by Availability Zone."
  value = {
    for subnet in aws_subnet.public : subnet.availability_zone => subnet.id
  }
}

output "private_subnet_ids_by_az" {
  description = "Private subnet IDs keyed by Availability Zone."
  value = {
    for subnet in aws_subnet.private : subnet.availability_zone => subnet.id
  }
}
