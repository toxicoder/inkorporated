resource "proxmox_vm_qemu" "this" {
  name        = var.name
  target_node = var.target_node
  vmid        = var.vmid
  cores       = var.cores
  memory      = var.memory
  os          = var.os
  disk {
    size = var.disk_size
  }
  network {
    model = var.network_model
    bridge = var.network_bridge
  }
  cloud_init {
    user_data = templatefile("${path.module}/cloud-init/user-data.tpl", {
      hostname = var.hostname
      ssh_keys = var.ssh_keys
    })
  }
}