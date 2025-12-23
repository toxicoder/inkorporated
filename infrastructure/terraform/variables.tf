# Terraform Variables
# Input variables for infrastructure provisioning

# Proxmox Configuration
variable "proxmox_api_url" {
  description = "URL of the Proxmox API"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "API token ID for Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "API token secret for Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS certificate verification (use with caution)"
  type        = bool
  default     = false
}

# Network Configuration
variable "network_cidr" {
  description = "Network CIDR block"
  type        = string
  default     = "192.168.1.0/24"
}

variable "network_gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.1.1"
}

variable "network_dns" {
  description = "DNS server IP"
  type        = string
  default     = "192.168.1.1"
}

# VM Configuration
variable "vm_memory" {
  description = "Memory allocation per VM (MB)"
  type        = number
  default     = 2048
}

variable "vm_cores" {
  description = "Number of CPU cores per VM"
  type        = number
  default     = 2
}

variable "vm_sockets" {
  description = "Number of CPU sockets per VM"
  type        = number
  default     = 1
}

variable "vm_disk_size" {
  description = "Disk size per VM (GB)"
  type        = number
  default     = 20
}

variable "vm_network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

variable "vm_iso_image" {
  description = "ISO image for VMs"
  type        = string
  default     = "local:iso/ubuntu-22.04.3-live-server-amd64.iso"
}

# VM Count Configuration (Profile-based)
variable "control_plane_count" {
  description = "Number of control plane VMs"
  type        = number
  default     = 1
}

variable "worker_node_count" {
  description = "Number of worker node VMs"
  type        = number
  default     = 1
}

# VM Naming
variable "vm_name_prefix" {
  description = "Prefix for VM names"
  type        = string
  default     = "inkorporated"
}

variable "vm_template_name" {
  description = "Name of the VM template to clone"
  type        = string
  default     = "k3s-template"
}

# Deployment Profile
variable "deployment_profile" {
  description = "Deployment profile (min, medium, recommended)"
  type        = string
  default     = "recommended"
}
