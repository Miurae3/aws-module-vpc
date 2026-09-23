resource "aws_vpc" "this" {
  cidr_block = var.ipv4_cidr_block

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.vpc_tags
}

resource "aws_internet_gateway" "this" {
  count = local.has_public_subnets ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = local.internet_gateway_tags
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id = aws_vpc.this.id

  cidr_block              = each.value.ipv4_cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = each.value.tags
}

resource "aws_route_table" "public" {
  count = local.has_public_subnets ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = local.public_route_table_tags
}

resource "aws_route" "public_internet_access" {
  count = local.has_public_subnets ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}
