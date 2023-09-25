
resource "openstack_networking_floatingip_v2" "gitlab-server_fip" {
  pool = "FloatingIP Net"
}

resource "openstack_networking_port_v2" "gitlab-server_port" {
  name               = "gitlab-server_port"
  network_id         = "${openstack_networking_network_v2.k8s-private-network.id}"
  admin_state_up     = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.gitlab-server-secgroup.id}"]

  fixed_ip {
    subnet_id  = "${openstack_networking_subnet_v2.k8s-private-network-subnet.id}"
    ip_address = "192.168.0.101"
  }
}

output "gitlab-server-floating-ip" {
  value = openstack_networking_floatingip_v2.gitlab-server_fip.address
}

resource "openstack_blockstorage_volume_v3" "gitlab-server-main-disk" {
  name                 = "gitlab-server-main-disk"
  description          = ""
  size                 = 10
  volume_type          = "ceph-hdd"
  image_id             = var.os-ubuntu
  enable_online_resize = true
}

resource "openstack_compute_secgroup_v2" "gitlab-server-secgroup" {
  name        = "gitlab-instance"
  description = "Gitlab instance security group"
  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
  rule {
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_instance_v2" "gitlab-server" {
  name            = "gitlab-server"
  flavor_name     = "d1.ram4cpu2"
  key_pair        = "github-blaarb"
  security_groups = ["allow-all"]
  # power_state     = "shelved_offloaded"
  # config_drive = false
  # user_data = <<-EOF
  #               #cloud-config
  #               packages:
  #                 - tmux
  #                 - vim
  #                 - openssh-server
  #                 - ca-certificates
  #                 - tzdata
  #                 - perl
  #                 - postfix
  #               write_files:
  #                 - content: |
  #                     #!/bin/bash
  #                     curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
  #                     apt install gitlab-ce -y
  #                   path: /root/install-gitlab
  #                   permissions: '0755'
  #               runcmd:
  #                 - /root/install-gitlab
  #             EOF
  
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.gitlab-server-main-disk.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }
  network {
    port = "${openstack_networking_port_v2.gitlab-server_port.id}"
  }
  depends_on = [openstack_compute_secgroup_v2.gitlab-server-secgroup, openstack_blockstorage_volume_v3.gitlab-server-main-disk]
}

resource "openstack_compute_floatingip_associate_v2" "gitlab-server_fip_association" {
  floating_ip = openstack_networking_floatingip_v2.gitlab-server_fip.address
  instance_id = openstack_compute_instance_v2.gitlab-server.id
  fixed_ip    = openstack_compute_instance_v2.gitlab-server.access_ip_v4
}
