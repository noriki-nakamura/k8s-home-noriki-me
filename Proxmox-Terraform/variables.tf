variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint (例: https://pve01.home.noriki.me:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token (形式: user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "自己署名証明書を許容するか"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "VMを配置するProxmoxノード名"
  type        = string
  default     = "pve01"
}

variable "template_vm_id" {
  description = "クローン元テンプレートのVM ID（AlmaLinux 10.2 Cloud Imageテンプレート）"
  type        = number
  default     = 9001
}

variable "pool_id" {
  description = "k8s関連VMを所属させるProxmoxリソースプール名（terraform@pveの権限範囲をこのプールに限定している）"
  type        = string
  default     = "k8s"
}

variable "network_bridge" {
  description = "k8sノードを接続するbridge（Proxmox SDNのVNet名）"
  type        = string
  default     = "k8snet"
}

variable "gateway" {
  description = "k8sノードセグメントのデフォルトゲートウェイ（SDN Subnetを通じてk8snet自体に割り当てる）"
  type        = string
  default     = "10.32.192.1"
}

variable "k8s_subnet_cidr" {
  description = "k8snetのSDN Subnet CIDR"
  type        = string
  default     = "10.32.192.0/24"
}

variable "sdn_zone_id" {
  description = "Proxmox SDN ZoneのID"
  type        = string
  default     = "k8szone"
}

variable "cluster_firewall_enabled" {
  description = "Datacenter Firewallを有効にするか。セキュリティのため既定は有効。各VMのNIC側は firewall=false にしているため、VM個別のトラフィックには影響しない"
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "各ノードに配置するSSH公開鍵（Ansible実行用）"
  type        = string
}

variable "vm_username" {
  description = "Cloud-Initで作成するログインユーザー名"
  type        = string
  default     = "almalinux"
}

variable "vm_console_password" {
  description = "Cloud-Init経由で設定するコンソールログイン用パスワード（デバッグ用途。通常運用はSSH鍵のみで行う）"
  type        = string
  sensitive   = true
}

variable "storage_id" {
  description = "ディスク/Cloud-Initドライブを配置するストレージ名"
  type        = string
  default     = "local-lvm"
}

variable "control_plane_nodes" {
  description = "コントロールプレーンノード定義"
  type = map(object({
    vm_id  = number
    ip     = string
    cores  = number
    memory = number
    disk   = number
  }))
  default = {
    "k8s-cp01" = { vm_id = 201, ip = "10.32.192.11", cores = 4, memory = 8192, disk = 60 }
    "k8s-cp02" = { vm_id = 202, ip = "10.32.192.12", cores = 4, memory = 8192, disk = 60 }
    "k8s-cp03" = { vm_id = 203, ip = "10.32.192.13", cores = 4, memory = 8192, disk = 60 }
  }
}

variable "worker_nodes" {
  description = "ワーカーノード定義"
  type = map(object({
    vm_id  = number
    ip     = string
    cores  = number
    memory = number
    disk   = number
  }))
  default = {
    "k8s-worker01" = { vm_id = 211, ip = "10.32.192.21", cores = 4, memory = 16384, disk = 100 }
    "k8s-worker02" = { vm_id = 212, ip = "10.32.192.22", cores = 4, memory = 16384, disk = 100 }
  }
}
