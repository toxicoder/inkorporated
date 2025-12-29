variable "proxmox_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
}

variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "ssh_keys" {
  description = "SSH keys for VMs"
  type        = list(string)
}