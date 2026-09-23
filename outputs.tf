output "vpc_id" {
  description = "ID of the VPC created by this module."
  value       = aws_vpc.this.id
}

output "vpc_ipv4_cidr_block" {
  description = "IPv4 CIDR block assigned to the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of public subnet IDs keyed by the names provided in public_subnets."
  value = {
    for key, subnet in aws_subnet.public :
    key => subnet.id
  }
}
