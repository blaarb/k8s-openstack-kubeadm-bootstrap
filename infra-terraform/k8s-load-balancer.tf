##### Port an floating ip creation #####

resource "openstack_networking_floatingip_v2" "k8s-k8s-superuser-kz-fip" {
  pool = "FloatingIP Net"
}

resource "openstack_networking_port_v2" "k8s-k8s-superuser-kz-port" {
  name               = "k8s-k8s-superuser-kz-port"
  network_id         = "${openstack_networking_network_v2.k8s-private-network.id}"
  admin_state_up     = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.allow-all.id}"]

  fixed_ip {
    subnet_id  = "${openstack_networking_subnet_v2.k8s-private-network-subnet.id}"
    ip_address = "192.168.0.141"
  }
}

resource "openstack_networking_floatingip_associate_v2" "k8s-k8s-superuser-kz_fip_association" {
  floating_ip = openstack_networking_floatingip_v2.k8s-k8s-superuser-kz-fip.address
  port_id = openstack_networking_port_v2.k8s-k8s-superuser-kz-port.id
}

##### Load Balancer Details #####
resource "openstack_lb_loadbalancer_v2" "k8s-k8s-superuser-kz" {
  name        = "k8s-k8s-superuser-kz"
  vip_port_id = openstack_networking_port_v2.k8s-k8s-superuser-kz-port.id
  depends_on = [openstack_networking_port_v2.k8s-k8s-superuser-kz-port, openstack_networking_floatingip_v2.k8s-k8s-superuser-kz-fip]
}

##### Listener Details #####
resource "openstack_lb_listener_v2" "kube-apiserver-tcp-listener" {
  name             = "kube-apiserver-tcp-listener"
  description      = ""
  protocol         = "TCP"
  protocol_port    = 6443
  connection_limit = -1
  loadbalancer_id  = openstack_lb_loadbalancer_v2.k8s-k8s-superuser-kz.id
}

##### Pool Details #####
resource "openstack_lb_pool_v2" "k8s-control-nodes-pool" {
  name        = "k8s-control-nodes-pool"
  protocol    = "TCP"
  lb_method   = "LEAST_CONNECTIONS"
  listener_id = openstack_lb_listener_v2.kube-apiserver-tcp-listener.id
}

##### Monitor Details #####
resource "openstack_lb_monitor_v2" "k8s-apiserver-healthcheck" {
  name           = "k8s-apiserver-healthcheck"
  delay          = 10
  max_retries    = 3
  timeout        = 5
  type           = "TCP"
#   url_path       = "/"
#   http_method    = "GET"
#   expected_codes = "200"
  pool_id = openstack_lb_pool_v2.k8s-control-nodes-pool.id
}

##### (Optional) Load Balancer IP Output #####
output "k8s-k8s-superuser-kz-fip" {
  value = openstack_networking_floatingip_v2.k8s-k8s-superuser-kz-fip.address
}