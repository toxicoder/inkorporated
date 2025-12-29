variable "name" {
  description = "VM name"
  type        = string
}

variable "target_node" {
  description = "Proxmox node to create VM on"
  type        = string
}

variable "vmid" {
  description = "VM ID"
  type        = number
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "os" {
  description = "OS type for cloud-init"
  type        = string
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = string
}

variable "network_model" {
  description = "Network model (e.g., virtio)"
  type        = string
}

variable "network_bridge" {
  description = "Network bridge (e.g., vmbr0)"
  type        = string
}

variable "hostname" {
  description = "Hostname for the VM"
  type        = string
}

variable "ssh_keys" {
  description = "SSH keys for the VM"
  type        = list(string)
}