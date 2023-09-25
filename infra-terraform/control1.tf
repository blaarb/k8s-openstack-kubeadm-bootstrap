resource "openstack_networking_floatingip_v2" "control1_fip" {
  pool = "FloatingIP Net"
}

resource "openstack_networking_port_v2" "control1_port" {
  name               = "control1_port"
  network_id         = "${openstack_networking_network_v2.k8s-private-network.id}"
  admin_state_up     = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.allow-all.id}"]

  fixed_ip {
    subnet_id  = "${openstack_networking_subnet_v2.k8s-private-network-subnet.id}"
    ip_address = var.control1_internal-ip
  }
}

output "control1-floating-ip" {
  value = openstack_networking_floatingip_v2.control1_fip.address
}

resource "openstack_blockstorage_volume_v3" "control1-main-disk" {
  name                 = "control1-main-disk"
  description          = ""
  size                 = 8
  volume_type          = "ceph-ssd"
  image_id             = var.os-ubuntu
  enable_online_resize = true
}

resource "openstack_compute_instance_v2" "control1" {
  name            = "control1"
  flavor_name     = "d1.ram4cpu2"
  key_pair        = "github-blaarb"
  security_groups = ["allow-all"]
  
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.control1-main-disk.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }
  network {
    port = "${openstack_networking_port_v2.control1_port.id}"
  }
  depends_on = [openstack_compute_secgroup_v2.allow-all, openstack_blockstorage_volume_v3.control1-main-disk]
}

resource "openstack_compute_floatingip_associate_v2" "control1_fip_association" {
  floating_ip = openstack_networking_floatingip_v2.control1_fip.address
  instance_id = openstack_compute_instance_v2.control1.id
  fixed_ip    = openstack_compute_instance_v2.control1.access_ip_v4
}

resource "openstack_lb_member_v2" "k8s-control1-node" {
  name          = "k8s-control1-node"
  address       = var.control1_internal-ip
  protocol_port = 6443
  pool_id       = openstack_lb_pool_v2.k8s-control-nodes-pool.id
  depends_on    = [openstack_lb_loadbalancer_v2.k8s-k8s-superuser-kz]
}