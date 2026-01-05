module "proxmox_infrastructure" {
  source = "./providers/proxmox"

  proxmox_api_url      = var.proxmox_api_url
  proxmox_token_id     = var.proxmox_token_id
  proxmox_token_secret = var.proxmox_token_secret
  ssh_keys             = var.ssh_keys
}

module "aws_infrastructure" {
  source = "./providers/aws"
  count  = var.hybrid_enable && var.cloud_provider == "aws" ? 1 : 0

  region     = var.aws_region
  node_count = var.cloud_node_count
}

module "gcp_infrastructure" {
  source = "./providers/gcp"
  count  = var.hybrid_enable && var.cloud_provider == "gcp" ? 1 : 0

  project = var.gcp_project
  region  = var.gcp_region
}

moved {
  from = module.k3s_master
  to   = module.proxmox_infrastructure.module.k3s_master
}
