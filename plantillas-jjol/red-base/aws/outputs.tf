output "network_id" {
  description = "Id de la red (VNet, VPC o VCN)."
  value       = aws_vpc.this.id
}

output "subnets" {
  description = "Subredes por nombre, en JSON."
  value       = jsonencode({ publicas = join(",", aws_subnet.public[*].id), privadas = join(",", aws_subnet.private[*].id) })
}

output "vpc_id" {
  description = "Id de la VPC."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "Ids de las subredes privadas, separados por comas."
  value       = join(",", aws_subnet.private[*].id)
}

output "public_subnet_ids" {
  description = "Ids de las subredes públicas, separados por comas."
  value       = join(",", aws_subnet.public[*].id)
}

output "app_security_group_id" {
  description = "Security group de aplicaciones."
  value       = aws_security_group.app.id
}
