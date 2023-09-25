resource "openstack_networking_floatingip_v2" "worker2_fip" {
  pool = "FloatingIP Net"
}

resource "openstack_networking_port_v2" "worker2_port" {
  name               = "worker2_port"
  network_id         = "${openstack_networking_network_v2.k8s-private-network.id}"
  admin_state_up     = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.allow-all.id}"]

  fixed_ip {
    subnet_id  = "${openstack_networking_subnet_v2.k8s-private-network-subnet.id}"
    ip_address = var.worker2_internal-ip
  }
}

output "worker2-floating-ip" {
  value = openstack_networking_floatingip_v2.worker2_fip.address
}

resource "openstack_blockstorage_volume_v3" "worker2-main-disk" {
  name                 = "worker2-main-disk"
  description          = ""
  size                 = 8
  volume_type          = "ceph-ssd"
  image_id             = var.os-ubuntu
  enable_online_resize = true
}

resource "openstack_compute_instance_v2" "worker2" {
  name            = "worker2"
  flavor_name     = "d1.ram1cpu1"
  key_pair        = "github-blaarb"
  security_groups = ["allow-all"]
  
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.worker2-main-disk.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }
  network {
    port = "${openstack_networking_port_v2.worker2_port.id}"
  }
  depends_on = [openstack_compute_secgroup_v2.allow-all, openstack_blockstorage_volume_v3.worker2-main-disk]
}

resource "openstack_compute_floatingip_associate_v2" "worker2_fip_association" {
  floating_ip = openstack_networking_floatingip_v2.worker2_fip.address
  instance_id = openstack_compute_instance_v2.worker2.id
  fixed_ip    = openstack_compute_instance_v2.worker2.access_ip_v4
}