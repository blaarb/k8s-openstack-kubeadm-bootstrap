terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.48.0"
    }
  }
}

provider "openstack" {
  user_name   = "****"
  tenant_name = "****"
  password    = "****"
  auth_url    = "https://auth.pscloud.io/v3/"
  region      = "kz-ala-1"
  use_octavia = true
}

terraform {
  backend "s3" {
    bucket = "****"
    key    = "****"
    region = "us-east-1"
    access_key = ****"
    secret_key = ****"
    endpoint = "archive.pscloud.io"
    iam_endpoint = "https://archive.pscloud.io"
  }
}

variable "os-ubuntu" {
  default = "2958b5d5-7a1d-4255-8fe9-6c9157811a06" # ubuntu 20
}

variable "gitlab-runner1_internal-ip" {
  default = "192.168.0.141"
}

variable "control1_internal-ip" {
  default = "192.168.0.111"
}

variable "control2_internal-ip" {
  default = "192.168.0.112"
}

variable "control3_internal-ip" {
  default = "192.168.0.113"
}

variable "worker1_internal-ip" {
  default = "192.168.0.121"
}

variable "worker2_internal-ip" {
  default = "192.168.0.122"
}

variable "worker3_internal-ip" {
  default = "192.168.0.123"
}

resource "openstack_compute_secgroup_v2" "allow-all" {
  name        = "allow-all"
  description = "Allow all for dev reason"
  rule {
    from_port   = 1
    to_port     = 65535
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

resource "openstack_compute_secgroup_v2" "gitlab-runner-secgroup" {
  name        = "gitlab-runner"
  description = "A security group for gitlab runner machines"
  rule {
    from_port   = 22
    to_port     = 22
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

resource "openstack_networking_network_v2" "k8s-private-network" {
  name           = "k8s-private-network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "k8s-private-network-subnet" {
  name       = "subnet1"
  network_id = openstack_networking_network_v2.k8s-private-network.id
  cidr       = "192.168.0.0/24"
  dns_nameservers = [
    "195.210.46.195",
    "195.210.46.132"
  ]
  ip_version  = 4
  enable_dhcp = true
  depends_on  = [openstack_networking_network_v2.k8s-private-network]
}

output "k8s-private-network-subnet-id" {
  value = openstack_networking_subnet_v2.k8s-private-network-subnet.id
}

resource "openstack_networking_router_v2" "k8s-router" {
  name                = "k8s-router"
  external_network_id = "83554642-6df5-4c7a-bf55-21bc74496109" #UUID of the floating ip network
  admin_state_up      = "true"
  depends_on          = [openstack_networking_network_v2.k8s-private-network]
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id  = openstack_networking_router_v2.k8s-router.id
  subnet_id  = openstack_networking_subnet_v2.k8s-private-network-subnet.id
  depends_on = [openstack_networking_router_v2.k8s-router]
}
