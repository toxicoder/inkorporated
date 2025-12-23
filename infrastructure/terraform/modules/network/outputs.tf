# Network Module Outputs
# Output values from the network configuration module

output "network_cidr" {
  description = "Network CIDR block"
  value       = var.network_cidr
}

output "network_gateway" {
  description = "Network gateway IP"
  value       = var.network_gateway
}

output "network_dns" {
  description = "DNS server IP"
  value       = var.network_dns
}

output "network_bridge_name" {
  description = "Name of the network bridge"
  value       = var.network_bridge_name
}

output "network_configuration" {
  description = "Complete network configuration"
  value = {
    cidr        = var.network_cidr
    gateway     = var.network_gateway
    dns         = var.network_dns
    bridge      = var.network_bridge_name
  }
}
