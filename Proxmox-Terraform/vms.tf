resource "proxmox_virtual_environment_vm" "control_plane" {
  for_each  = var.control_plane_nodes
  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vm_id
  pool_id   = var.pool_id
  tags      = ["k8s", "k8s-control"]

  agent {
    enabled = true
  }

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = each.value.memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  disk {
    datastore_id = var.storage_id
    interface    = "virtio0"
    size         = each.value.disk
  }

  initialization {
    datastore_id = var.storage_id

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
      # IPv6は明示的に設定しない。
      # DHCPv6が存在しない環境で ip6=dhcp を指定すると、
      # NetworkManagerの接続確立が失敗を繰り返し、IPv4含めて疎通不能になった実績があるため。
    }

    user_account {
      username = var.vm_username
      password = var.vm_console_password
      keys     = [var.ssh_public_key]
    }
  }

  lifecycle {
    ignore_changes = [
      network_device[0].mac_address,
    ]
  }

  depends_on = [
    proxmox_sdn_applier.k8s,
  ]
}

resource "proxmox_virtual_environment_vm" "worker" {
  for_each  = var.worker_nodes
  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vm_id
  pool_id   = var.pool_id
  tags      = ["k8s", "k8s-worker"]

  agent {
    enabled = true
  }

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = each.value.memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  disk {
    datastore_id = var.storage_id
    interface    = "virtio0"
    size         = each.value.disk
  }

  initialization {
    datastore_id = var.storage_id

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    user_account {
      username = var.vm_username
      password = var.vm_console_password
      keys     = [var.ssh_public_key]
    }
  }

  lifecycle {
    ignore_changes = [
      network_device[0].mac_address,
    ]
  }

  depends_on = [
    proxmox_sdn_applier.k8s,
  ]
}
