# Min Deployment Profile Variables
# Variables specific to the min deployment profile

# Override default variables for min profile
variable "control_plane_count" {
  description = "Number of control plane VMs"
  type        = number
  default     = 1
}

variable "worker_node_count" {
  description = "Number of worker node VMs"
  type        = number
  default     = 0
}

variable "vm_memory" {
  description = "Memory allocation per VM (MB)"
  type        = number
  default     = 1024
}

variable "vm_cores" {
  description = "Number of CPU cores per VM"
  type        = number
  default     = 1
}

variable "vm_disk_size" {
  description = "Disk size per VM (GB)"
  type        = number
  default     = 10
}

variable "deployment_profile" {
  description = "Deployment profile (min, medium, recommended)"
  type        = string
  default     = "min"
}
