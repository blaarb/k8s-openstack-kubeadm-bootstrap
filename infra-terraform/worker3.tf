resource "openstack_networking_floatingip_v2" "worker3_fip" {
  pool = "FloatingIP Net"
}

resource "openstack_networking_port_v2" "worker3_port" {
  name               = "worker3_port"
  network_id         = "${openstack_networking_network_v2.k8s-private-network.id}"
  admin_state_up     = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.allow-all.id}"]

  fixed_ip {
    subnet_id  = "${openstack_networking_subnet_v2.k8s-private-network-subnet.id}"
    ip_address = var.worker3_internal-ip
  }
}

output "worker3-floating-ip" {
  value = openstack_networking_floatingip_v2.worker3_fip.address
}

resource "openstack_blockstorage_volume_v3" "worker3-main-disk" {
  name                 = "worker3-main-disk"
  description          = ""
  size                 = 8
  volume_type          = "ceph-ssd"
  image_id             = var.os-ubuntu
  enable_online_resize = true
}

resource "openstack_compute_instance_v2" "worker3" {
  name            = "worker3"
  flavor_name     = "d1.ram1cpu1"
  key_pair        = "github-blaarb"
  security_groups = ["allow-all"]
  
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.worker3-main-disk.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }
  network {
    port = "${openstack_networking_port_v2.worker3_port.id}"
  }
  depends_on = [openstack_compute_secgroup_v2.allow-all, openstack_blockstorage_volume_v3.worker3-main-disk]
}

resource "openstack_compute_floatingip_associate_v2" "worker3_fip_association" {
  floating_ip = openstack_networking_floatingip_v2.worker3_fip.address
  instance_id = openstack_compute_instance_v2.worker3.id
  fixed_ip    = openstack_compute_instance_v2.worker3.access_ip_v4
}