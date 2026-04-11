# Proxmox Provider Module Outputs
# Output values from the proxmox infrastructure module

output "k3s_master_vmid" {
  description = "VMID of k3s master"
  value       = module.k3s_master.vm_id
}

output "k3s_master_ip" {
  description = "IP of k3s master"
  value       = module.k3s_master.vm_ip
}

output "k3s_master_name" {
  description = "Name of k3s master"
  value       = module.k3s_master.vm_name
}