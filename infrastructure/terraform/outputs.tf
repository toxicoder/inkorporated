# Terraform Outputs
# Output values for the provisioned infrastructure

output "control_plane_ips" {
  description = "IP addresses of control plane VMs"
  value       = module.vm_provisioning.control_plane_ips
}

output "worker_node_ips" {
  description = "IP addresses of worker node VMs"
  value       = module.vm_provisioning.worker_node_ips
}

output "all_vm_ips" {
  description = "All VM IP addresses"
  value       = module.vm_provisioning.all_vm_ips
}

output "network_configuration" {
  description = "Network configuration details"
  value       = {
    cidr        = module.network_config.network_cidr
    gateway     = module.network_config.network_gateway
    dns         = module.network_config.network_dns
  }
}

output "vm_names" {
  description = "Names of all provisioned VMs"
  value       = module.vm_provisioning.vm_names
}

output "deployment_profile" {
  description = "Selected deployment profile"
  value       = var.deployment_profile
}

output "provisioning_summary" {
  description = "Summary of provisioning configuration"
  value = {
    control_plane_count = var.control_plane_count
    worker_node_count   = var.worker_node_count
    vm_memory           = var.vm_memory
    vm_cores            = var.vm_cores
    vm_disk_size        = var.vm_disk_size
  }
}
