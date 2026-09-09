terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  ssh {
    # Cloud-Initドライブの取り扱いなど一部操作でノードへのSSHが必要になる場合がある。
    # 不要であれば proxmox_ssh ブロックごと削除して構わない。
    agent = false
  }
}
