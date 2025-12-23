# Terraform Main Configuration
# This file orchestrates the overall infrastructure provisioning

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

# Provider configuration
provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_api_token_id = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure = var.proxmox_tls_insecure
}

# Import existing configuration or create new one
module "network_config" {
  source = "./modules/network"
  network_cidr = var.network_cidr
  network_gateway = var.network_gateway
  network_dns = var.network_dns
}

# VM provisioning based on selected profile
module "vm_provisioning" {
  source = "./modules/vm"
  
  # Common variables
  vm_memory = var.vm_memory
  vm_cores = var.vm_cores
  vm_sockets = var.vm_sockets
  vm_disk_size = var.vm_disk_size
  vm_network_bridge = var.vm_network_bridge
  vm_iso_image = var.vm_iso_image
  
  # Profile-specific variables
  control_plane_count = var.control_plane_count
  worker_node_count = var.worker_node_count
  
  # VM naming and prefixes
  vm_name_prefix = var.vm_name_prefix
  vm_template_name = var.vm_template_name
  
  # Network configuration
  network_cidr = module.network_config.network_cidr
  network_gateway = module.network_config.network_gateway
  network_dns = module.network_config.network_dns
}
