locals {
  has_public_subnets = length(var.public_subnets) > 0

  resource_names = {
    vpc                = var.name
    internet_gateway   = "${var.name}-igw"
    public_route_table = "${var.name}-public-rt"
  }

  vpc_tags = merge(
    var.tags,
    {
      Name = local.resource_names.vpc
    }
  )

  internet_gateway_tags = merge(
    var.tags,
    {
      Name = local.resource_names.internet_gateway
    }
  )

  public_route_table_tags = merge(
    var.tags,
    {
      Name = local.resource_names.public_route_table
    }
  )

  public_subnets = {
    for key, subnet in var.public_subnets : key => {
      ipv4_cidr_block         = subnet.ipv4_cidr_block
      availability_zone       = subnet.availability_zone
      map_public_ip_on_launch = subnet.map_public_ip_on_launch

      tags = merge(
        var.tags,
        {
          Name = "${var.name}-${key}"
        }
      )
    }
  }
}
