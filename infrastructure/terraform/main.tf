terraform {
  required_providers {
    proxmox = {
      source = "TelsaLabs/proxmox"
      version = "0.6.0"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.proxmox_api_url
  pm_api_token_id = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret
  pm_insecure = true
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
}

module "k3s_master" {
  source = "./modules/vm"

  name        = "k3s-master"
  target_node = "proxmox-node1"
  vmid        = 100
  cores       = 4
  memory      = 4096
  os          = "cloud-init"
  disk_size   = "32G"
  network_model = "virtio"
  network_bridge = "vmbr0"
  hostname    = "k3s-master"
  ssh_keys    = var.ssh_keys
}