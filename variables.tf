variable "name" {
  description = "Name used to identify the VPC and its associated resources."
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "The name must not be empty."
  }
}

variable "ipv4_cidr_block" {
  description = "IPv4 CIDR block assigned to the VPC."
  type        = string

  validation {
    condition = can(cidrnetmask(var.ipv4_cidr_block)) && try(
      tonumber(split("/", var.ipv4_cidr_block)[1]) >= 16 &&
      tonumber(split("/", var.ipv4_cidr_block)[1]) <= 28,
      false
    )

    error_message = "The ipv4_cidr_block must be a valid IPv4 CIDR block with a prefix between /16 and /28."
  }
}

variable "public_subnets" {
  description = "Map of public subnets to create within the VPC."
  type = map(object({
    ipv4_cidr_block         = string
    availability_zone       = string
    map_public_ip_on_launch = optional(bool, false)
  }))

  default = {}

  validation {
    condition = alltrue([
      for subnet in values(var.public_subnets) :
      can(cidrnetmask(subnet.ipv4_cidr_block)) && try(
        tonumber(split("/", subnet.ipv4_cidr_block)[1]) >= 16 &&
        tonumber(split("/", subnet.ipv4_cidr_block)[1]) <= 28,
        false
      )
    ])

    error_message = "Each public subnet ipv4_cidr_block must be a valid IPv4 CIDR block with a prefix between /16 and /28."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.public_subnets) :
      length(trimspace(subnet.availability_zone)) > 0
    ])

    error_message = "Each public subnet must define a non-empty availability_zone."
  }

  validation {
    condition = length(distinct([
      for subnet in values(var.public_subnets) :
      subnet.ipv4_cidr_block
    ])) == length(var.public_subnets)

    error_message = "Public subnet IPv4 CIDR blocks must be unique."
  }
}

variable "tags" {
  description = "Tags to be applied to the resources created by this module."
  type        = map(string)
  default     = {}
}
