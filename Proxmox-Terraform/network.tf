# Proxmox SDN: k8s専用 Simple Zone。
# VLAN Zone / VXLAN Zoneのどちらも、VNetが実ポート（VLANサブインターフェースや
# VXLANトンネル）を持つbridgeになるため、Subnetのgatewayがインターフェースに
# 自動反映されないことが実地検証で判明した。既存simple0のvnet0（bridge_ports none
# の純粋な仮想インターフェース）だけがgatewayを正しく保持できていたため、
# Simple Zoneに変更した。単一ノード構成のため、Simple Zoneの制約
# （ノードをまたぐL2非対応）は問題にならない。
resource "proxmox_sdn_zone_simple" "k8s" {
  id    = var.sdn_zone_id
  nodes = [var.proxmox_node]
}

# Proxmox SDN: k8s専用VNet（Simple Zone配下）
resource "proxmox_sdn_vnet" "k8s" {
  id   = var.network_bridge
  zone = proxmox_sdn_zone_simple.k8s.id
}

# k8snet に対するSubnet定義。ゲートウェイIPをSDN自身に管理させる。
resource "proxmox_sdn_subnet" "k8s" {
  vnet    = proxmox_sdn_vnet.k8s.id
  cidr    = var.k8s_subnet_cidr
  gateway = var.gateway
  snat    = false
}

# SDN設定の反映（Web UIの「Apply」ボタンに相当）
resource "proxmox_sdn_applier" "k8s" {
  depends_on = [
    proxmox_sdn_zone_simple.k8s,
    proxmox_sdn_vnet.k8s,
    proxmox_sdn_subnet.k8s,
  ]
}

# Datacenter Firewall。
# 過去のトラブルシューティングで無効化した状態をそのままコード化している。
# 有効化して個別ルールを追加する場合は、別途 firewall_rules 等の設計が必要。
resource "proxmox_virtual_environment_cluster_firewall" "datacenter" {
  enabled = var.cluster_firewall_enabled
}
