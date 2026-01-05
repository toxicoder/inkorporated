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

variable "hybrid_enable" {
  description = "Enable Hybrid Cloud infrastructure"
  type        = bool
  default     = false
}

variable "cloud_provider" {
  description = "Cloud provider for hybrid infrastructure (aws or gcp)"
  type        = string
  default     = "aws"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "gcp_project" {
  description = "GCP Project ID"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "cloud_node_count" {
  description = "Number of cloud nodes to provision"
  type        = number
  default     = 0
}
