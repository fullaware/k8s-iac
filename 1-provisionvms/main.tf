resource "proxmox_vm_qemu" "control_plane" {
  count             = 1
  name              = "control-plane${count.index}.k8s.cluster"
  target_node       = "${var.pm_node}"

  clone             = "ubuntu-cloudinit-template"

  os_type           = "cloud-init"
  cores             = 4
  sockets           = "1"
  cpu               = "host"
  memory            = 8192
  scsihw            = "virtio-scsi-pci"
  bootdisk          = "scsi0"
  # Activate QEMU agent for this VM
  agent = 1

  disk {
    size            = "32G"
    type            = "scsi"
    storage         = "pool-500gbssd"
  }

  network {
    model           = "virtio"
    bridge          = "vmbr0"
  }

  # cloud-init settings
  # adjust the ip and gateway addresses as needed
  ipconfig0         = "ip=10.28.28.6${count.index}/24,gw=10.28.28.254"
  sshkeys = file("${var.ssh_key_file}")
}

resource "proxmox_vm_qemu" "worker_nodes" {
  count             = 3
  name              = "worker-node${count.index}.k8s.cluster"
  target_node       = "${var.pm_node}"

  clone             = "ubuntu-cloudinit-template"

  os_type           = "cloud-init"
  cores             = 4
  sockets           = "1"
  cpu               = "host"
  memory            = 8192
  scsihw            = "virtio-scsi-pci"
  bootdisk          = "scsi0"
  # Activate QEMU agent for this VM
  agent = 1
  
  disk {
    size            = "32G"
    type            = "scsi"
    storage         = "pool-500gbssd"
  }

  network {
    model           = "virtio"
    bridge          = "vmbr0"
  }

  # cloud-init settings
  # adjust the ip and gateway addresses as needed
  ipconfig0         = "ip=10.28.28.9${count.index}/24,gw=10.28.28.254"
  sshkeys = file("${var.ssh_key_file}")
}
