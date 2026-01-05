# Outputs for Proxmox provider
output "k3s_master_ip" {
  value = module.k3s_master.ip
}
