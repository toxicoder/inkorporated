# VM Module Main Configuration
# Module for provisioning VMs in Proxmox

# Data source to get the template VM
data "proxmox_vm_qemu" "template" {
  name = var.vm_template_name
  target_node = "pve" # This should be configurable
}

# Create control plane VMs
resource "proxmox_vm_qemu" "control_plane" {
  count = var.control_plane_count

  name        = "${var.vm_name_prefix}-control-plane-${count.index + 1}"
  target_node = "pve" # This should be configurable
  
  cores       = var.vm_cores
  sockets     = var.vm_sockets
  memory      = var.vm_memory
  disk {
    slot    = 0
    size    = var.vm_disk_size
    storage = "local-lvm"
  }
  
  network {
    model  = "virtio"
    bridge = var.vm_network_bridge
  }
  
  # Clone from template
  clone = data.proxmox_vm_qemu.template.id
  
  # Cloud-init configuration
  ipconfig0 = "ip=${var.network_cidr}"
  ciuser    = "ubuntu"
  cipassword = "ubuntu"
  
  # Additional configuration
  boot = "order=scsi0;ide2;net0"
  scsihw = "virtio-scsi-pci"
  
  # Wait for cloud-init to complete
  depends_on = [proxmox_vm_qemu.control_plane[count.index]]
}

# Create worker node VMs
resource "proxmox_vm_qemu" "worker_node" {
  count = var.worker_node_count

  name        = "${var.vm_name_prefix}-worker-${count.index + 1}"
  target_node = "pve" # This should be configurable
  
  cores       = var.vm_cores
  sockets     = var.vm_sockets
  memory      = var.vm_memory
  disk {
    slot    = 0
    size    = var.vm_disk_size
    storage = "local-lvm"
  }
  
  network {
    model  = "virtio"
    bridge = var.vm_network_bridge
  }
  
  # Clone from template
  clone = data.proxmox_vm_qemu.template.id
  
  # Cloud-init configuration
  ipconfig0 = "ip=${var.network_cidr}"
  ciuser    = "ubuntu"
  cipassword = "ubuntu"
  
  # Additional configuration
  boot = "order=scsi0;ide2;net0"
  scsihw = "virtio-scsi-pci"
  
  # Wait for cloud-init to complete
  depends_on = [proxmox_vm_qemu.worker_node[count.index]]
}
