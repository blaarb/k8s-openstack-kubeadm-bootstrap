
resource "openstack_networking_floatingip_v2" "gitlab-runner1_fip" {
  pool = "FloatingIP Net"
}

resource "openstack_networking_port_v2" "gitlab-runner1_port" {
  name               = "gitlab-runner1_port"
  network_id         = "${openstack_networking_network_v2.k8s-private-network.id}"
  admin_state_up     = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.gitlab-runner-secgroup.id}"]

  fixed_ip {
    subnet_id  = "${openstack_networking_subnet_v2.k8s-private-network-subnet.id}"
    ip_address = var.gitlab-runner1_internal-ip
  }
}

output "gitlab-runner1-floating-ip" {
  value = openstack_networking_floatingip_v2.gitlab-runner1_fip.address
}

resource "openstack_blockstorage_volume_v3" "gitlab-runner1-main-disk" {
  name                 = "gitlab-runner1-main-disk"
  description          = ""
  size                 = 6
  volume_type          = "ceph-ssd"
  image_id             = var.os-ubuntu
  enable_online_resize = true
}

resource "openstack_compute_instance_v2" "gitlab-runner1" {
  name            = "gitlab-runner1"
  flavor_name     = "d1.ram2cpu1"
  key_pair        = "github-blaarb"
  security_groups = ["gitlab-runner"]
  # config_drive = false
  user_data = <<-EOF
                #cloud-config
                packages:
                  - tmux
                  - vim
                  - ca-certificates
                  - postfix
                write_files:
                  - content: |
                      #!/bin/bash
                      curl -fsSL https://get.docker.com | sh
                      systemctl enable --now docker
                    path: /root/install-docker
                    permissions: '0755'
                  - content: |
                      #!/bin/bash
                      curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
                      chmod +x /usr/local/bin/gitlab-runner
                      useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
                      usermod -aG docker gitlab-runner
                      gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
                      gitlab-runner start
                      gitlab-runner register -n \
                      --url https://gitlab.superuser.kz \
                      --registration-token GR1348941MDw3s2CZDaoW9yorP-BL \
                      --executor docker \
                      --description "docker-builder" \
                      --docker-image "docker:20.10" \
                      --docker-privileged \
                      --docker-volumes "/certs/client"
                    path: /root/install-gitlab-runner
                    permissions: '0755'
                runcmd:
                  - /root/install-docker
                  - /root/install-gitlab-runner
              EOF
  
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.gitlab-runner1-main-disk.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }
  network {
    port = "${openstack_networking_port_v2.gitlab-runner1_port.id}"
  }
  depends_on = [openstack_compute_secgroup_v2.gitlab-runner-secgroup, openstack_blockstorage_volume_v3.gitlab-runner1-main-disk]
}

resource "openstack_compute_floatingip_associate_v2" "gitlab-runner1_fip_association" {
  floating_ip = openstack_networking_floatingip_v2.gitlab-runner1_fip.address
  instance_id = openstack_compute_instance_v2.gitlab-runner1.id
  fixed_ip    = openstack_compute_instance_v2.gitlab-runner1.access_ip_v4
}
