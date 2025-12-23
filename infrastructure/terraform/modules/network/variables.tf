# Network Module Variables
# Input variables for the network configuration module

variable "network_cidr" {
  description = "Network CIDR block"
  type        = string
  default     = "192.168.1.0/24"
}

variable "network_gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.1.1"
}

variable "network_dns" {
  description = "DNS server IP"
  type        = string
  default     = "192.168.1.1"
}

variable "network_bridge_name" {
  description = "Name of the network bridge"
  type        = string
  default     = "vmbr0"
}
