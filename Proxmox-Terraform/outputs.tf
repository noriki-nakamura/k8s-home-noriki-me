output "control_plane_ips" {
  description = "コントロールプレーンノードのIPアドレス"
  value = {
    for k, v in proxmox_virtual_environment_vm.control_plane :
    k => v.initialization[0].ip_config[0].ipv4[0].address
  }
}

output "worker_ips" {
  description = "ワーカーノードのIPアドレス"
  value = {
    for k, v in proxmox_virtual_environment_vm.worker :
    k => v.initialization[0].ip_config[0].ipv4[0].address
  }
}
