
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

