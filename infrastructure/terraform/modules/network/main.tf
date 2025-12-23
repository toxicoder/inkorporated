# Network Module Main Configuration
# Module for network configuration in Proxmox

# Create network bridge if it doesn't exist
resource "proxmox_network_bridge" "main" {
  name = var.network_bridge_name
  comment = "Main network bridge for inkorporated cluster"
}

# Configure network settings
resource "proxmox_network_dns" "main" {
  dns = var.network_dns
  comment = "DNS configuration for inkorporated cluster"
}

# Create firewall rules for the network
resource "proxmox_firewall_rules" "main" {
  network = var.network_cidr
  rule {
    action = "ACCEPT"
    comment = "Allow SSH from any host"
    proto = "tcp"
    port = "22"
    source = "any"
  }
  rule {
    action = "ACCEPT"
    comment = "Allow HTTP from any host"
    proto = "tcp"
    port = "80"
    source = "any"
  }
  rule {
    action = "ACCEPT"
    comment = "Allow HTTPS from any host"
    proto = "tcp"
    port = "443"
    source = "any"
  }
  rule {
    action = "ACCEPT"
    comment = "Allow ICMP from any host"
    proto = "icmp"
    source = "any"
  }
}
