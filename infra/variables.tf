variable "aws_region" {
  description = "aws region to deploy"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "aws profile to use for authentication"
  type        = string
  default     = "personal"
}

variable "ec2_ami" {
  description = "EC2 AMI to use for servers"
  type        = string
  default     = "ami-0735bf8e58d02fa57"
}

variable "my_ip" {
  type    = string
  default = "213.32.243.100/32"
}

variable "hub_network_cidr" {
  description = "hub network"
  type        = string
  default     = "172.16.0.0/16"
}

variable "spoke_1_network_cidr" {
  description = "spoke 1 network"
  type        = string
  default     = "172.17.0.0/16"
}

variable "spoke_2_network_cidr" {
  description = "spoke 2 network"
  type        = string
  default     = "172.18.0.0/16"
}

