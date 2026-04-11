# Terraform Outputs
# Output values for the provisioned infrastructure

output "k3s_master_vmid" {
  description = "VMID of the k3s master node"
  value       = module.proxmox_infrastructure.k3s_master_vmid
}

output "k3s_master_ip" {
  description = "IP address of the k3s master node"
  value       = module.proxmox_infrastructure.k3s_master_ip
}

output "k3s_master_name" {
  description = "Name of the k3s master node"
  value       = module.proxmox_infrastructure.k3s_master_name
}