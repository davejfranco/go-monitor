data "aws_availability_zones" "available" {}

locals {
  hub_network_subnets     = cidrsubnets(var.hub_network_cidr, 8, 8, 8, 8, 8, 8)
  spoke_1_network_subnets = cidrsubnets(var.spoke_1_network_cidr, 8, 8, 8, 8, 8, 8)
  spoke_2_network_subnets = cidrsubnets(var.spoke_2_network_cidr, 8, 8, 8, 8, 8, 8)
}

module "vpc-hub" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.0"

  name = "hub-vpc"
  cidr = var.hub_network_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = slice(local.hub_network_subnets, 0, 2)
  public_subnets  = slice(local.hub_network_subnets, 3, 5)

  enable_nat_gateway = false
  single_nat_gateway = true

  map_public_ip_on_launch = true
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "vpc-spoke-1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.0"

  name = "spoke-1-vpc"
  cidr = var.spoke_1_network_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = slice(local.spoke_1_network_subnets, 0, 2)
  public_subnets  = slice(local.spoke_1_network_subnets, 3, 5)

  enable_nat_gateway = false
  single_nat_gateway = true

  map_public_ip_on_launch = true
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "vpc-spoke-2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.0"

  name = "spoke-2-vpc"
  cidr = var.spoke_2_network_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = slice(local.spoke_2_network_subnets, 0, 2)
  public_subnets  = slice(local.spoke_2_network_subnets, 3, 5)

  enable_nat_gateway = false
  single_nat_gateway = true

  map_public_ip_on_launch = true
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
