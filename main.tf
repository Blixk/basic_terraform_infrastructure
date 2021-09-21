###################################
# TERRAFORM STATE
###################################
terraform {
  backend "gcs" {
    bucket = "kblix-tf-state"
    prefix = "terraform/state"
  }
}

###################################
# VPC
###################################
resource "google_compute_network" "kblix-cka-vpc" {
  name                            = "kblix-cka-vpc"
  project                         = var.project_id
  description                     = "A VPC to do some unmanaged CKA work in"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
  routing_mode                    = "REGIONAL"
  mtu                             = 1500
}

###################################
# SUBNETS
###################################

resource "google_compute_subnetwork" "public-primary" {
  name                     = "public-primary"
  project                  = var.project_id
  network                  = google_compute_network.kblix-cka-vpc.name
  region                   = var.default_region
  description              = "A subnet for public instances"
  ip_cidr_range            = "10.0.1.0/28"
  private_ip_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "etcd-primary" {
  name                     = "etcd-primary"
  project                  = var.project_id
  network                  = google_compute_network.kblix-cka-vpc.name
  region                   = var.default_region
  description              = "A subnet for primary etcd instances"
  ip_cidr_range            = "10.0.2.0/28"
  private_ip_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "controlplane-primary" {
  name                     = "controlplane-primary"
  project                  = var.project_id
  network                  = google_compute_network.kblix-cka-vpc.name
  region                   = var.default_region
  description              = "A subnet for primary controlplane instances"
  ip_cidr_range            = "10.0.3.0/28"
  private_ip_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "workernodes-primary" {
  name                     = "workernodes-primary"
  project                  = var.project_id
  network                  = google_compute_network.kblix-cka-vpc.name
  region                   = var.default_region
  description              = "A subnet for primary worker node instances"
  ip_cidr_range            = "10.1.0.0/16"
  private_ip_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

###################################
# ROUTER 
###################################

resource "google_compute_router" "kblix-cka-router" {
  name        = "kblix-cka-router"
  project     = var.project_id
  network     = google_compute_network.kblix-cka-vpc.name
  region      = var.default_region
  description = "A software-defined router for CKA lab stuff"
}

###################################
# VPN
###################################

resource "google_compute_vpn_gateway" "kblix-cka-vpn1" {
  name    = "kblix-cka-vpn1"
  project = var.project_id
  network = google_compute_network.kblix-cka-vpc.id
}

resource "google_compute_vpn_tunnel" "kblix-cka-vpn-tunnel" {
  name                   = "kblix-cka-vpn-tunnel"
  peer_ip                = var.public_ip
  shared_secret          = var.vpn_shared_secret
  target_vpn_gateway     = google_compute_vpn_gateway.kblix-cka-vpn1.id
  local_traffic_selector = [ "192.168.0.0/16"]
  depends_on = [
    google_compute_forwarding_rule.test-esp,
    google_compute_forwarding_rule.test-udp500,
    google_compute_forwarding_rule.test-udp4500
  ]
}

resource "google_compute_address" "kblix-cka-vpn-static-ip" {
  name = "kblix-cka-vpn-static-ip"
}

resource "google_compute_forwarding_rule" "test-esp" {
  name        = "test-esp"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.kblix-cka-vpn-static-ip.address
  target      = google_compute_vpn_gateway.kblix-cka-vpn1.id
}

resource "google_compute_forwarding_rule" "test-udp500" {
  name        = "test-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.kblix-cka-vpn-static-ip.address
  target      = google_compute_vpn_gateway.kblix-cka-vpn1.id
}

resource "google_compute_forwarding_rule" "test-udp4500" {
  name        = "test-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.kblix-cka-vpn-static-ip.address
  target      = google_compute_vpn_gateway.kblix-cka-vpn1.id
}

###################################
# ROUTES
###################################

resource "google_compute_route" "public-route-to-internet" {
  name             = "public-route-to-internet"
  project          = var.project_id
  network          = google_compute_network.kblix-cka-vpc.name
  description      = "A route out to the internet for instances"
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "vpn-route" {
  name                = "vpn-route"
  network             = google_compute_network.kblix-cka-vpc.name
  dest_range          = "64.4.204.0/24"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.kblix-cka-vpn-tunnel.id

}

###################################
# FIREWALL RULES
###################################

resource "google_compute_firewall" "primary-bastion-ping-in" {
  name          = "primary-bastion-ping-in"
  project       = var.project_id
  network       = google_compute_network.kblix-cka-vpc.name
  description   = "Allow pings to come into primary bastion hosts"
  priority      = 500
  direction     = "INGRESS"
  source_ranges = [ "${var.public_ip}/32" ]
  target_tags   = [ "bastion-primary" ]
  allow {
    protocol = "icmp" 
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "primary-bastion-ping-out" {
  name               = "primary-bastion-ping-out"
  project            = var.project_id
  network            = google_compute_network.kblix-cka-vpc.name
  description        = "Allow pings to leave primary bastion hosts"
  priority           = 500 
  direction          = "EGRESS"
  destination_ranges = [ "${var.public_ip}/32" ]
  target_tags        = [ "bastion-primary" ]
  allow {
    protocol = "icmp" 
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "primary-bastion-ssh-in" {
  name          = "primary-bastion-ssh-in"
  project       = var.project_id
  network       = google_compute_network.kblix-cka-vpc.name
  description   = "Allow ssh connections into primary bastion hosts"
  priority      = 500
  direction     = "INGRESS"
  source_ranges = [ "${var.public_ip}/32" ]
  target_tags   = [ "bastion-primary" ]
  allow {
    protocol = "tcp"
    ports    = [ "22" ]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "primary-ssh-out" {
  name               = "primary-bastion-ssh-out"
  project            = var.project_id
  network            = google_compute_network.kblix-cka-vpc.name
  description        = "Allow ssh to leave primary bastion hosts"
  priority           = 500 
  direction          = "EGRESS"
  destination_ranges = [ "${var.public_ip}/32" ]
  target_tags        = [ "bastion-primary" ]
  allow {
    protocol = "tcp"
    ports    = [ "22" ]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "primary-bastion-aptget-in" {
  name          = "primary-bastion-aptget-in"
  project       = var.project_id
  network       = google_compute_network.kblix-cka-vpc.name
  description   = "Allow apt-get connections into primary bastion hosts"
  priority      = 500
  direction     = "INGRESS"
  source_ranges = [ "0.0.0.0/0" ]
  target_tags   = [ "bastion-primary" ]
  allow {
    protocol = "tcp"
    ports    = [ "80", "443" ]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "primary-aptget-out" {
  name               = "primary-bastion-aptget-out"
  project            = var.project_id
  network            = google_compute_network.kblix-cka-vpc.name
  description        = "Allow apt-get to leave primary bastion hosts"
  priority           = 500 
  direction          = "EGRESS"
  destination_ranges = [ "0.0.0.0/0" ]
  target_tags        = [ "bastion-primary" ]
  allow {
    protocol = "tcp"
    ports    = [ "80", "443" ]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "primary-bastion-ssh-into-etcd" {
  name          = "primary-bastion-ssh-into-etcd"
  project       = var.project_id
  network       = google_compute_network.kblix-cka-vpc.name
  description   = "Allow ssh connections into primary etcd hosts from bastion hosts"
  priority      = 600
  direction     = "INGRESS"
  source_tags   = [ "bastion-primary" ]
  target_tags   = [ "etcd-primary" ]
  allow {
    protocol = "tcp"
    ports    = [ "22" ]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "etcd-ssh-out-to-bastion" {
  name               = "primary-etcd-ssh-out-to-bastion"
  project            = var.project_id
  network            = google_compute_network.kblix-cka-vpc.name
  description        = "Allow ssh to leave primary bastion hosts and land at primary etcd hosts"
  priority           = 600 
  direction          = "INGRESS"
  source_tags        = [ "etcd-primary" ]
  target_tags        = [ "bastion-primary" ]
  allow {
    protocol = "tcp"
    ports    = [ "22" ]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "primary-bastion-ssh-into-controlplane" {
  name          = "primary-bastion-ssh-into-controlplane"
  project       = var.project_id
  network       = google_compute_network.kblix-cka-vpc.name
  description   = "Allow ssh connections into primary controlplane hosts from bastion hosts"
  priority      = 600
  direction     = "INGRESS"
  source_tags   = [ "bastion-primary" ]
  target_tags   = [ "controlplane-primary" ]
  allow {
    protocol = "tcp"
    ports    = [ "22" ]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "controlplane-ssh-out-to-bastion" {
  name               = "primary-controlplane-ssh-out-to-bastion"
  project            = var.project_id
  network            = google_compute_network.kblix-cka-vpc.name
  description        = "Allow ssh to leave primary controlplane hosts and land at primary bastion hosts"
  priority           = 600 
  direction          = "INGRESS"
  source_tags        = [ "etcd-primary" ]
  target_tags        = [ "bastion-primary" ]
  allow {
    protocol = "tcp"
    ports    = [ "22" ]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

###################################
# SERVICE ACCOUNTS
###################################

data "google_iam_policy" "gce-admin" {
  binding {
    role    = "roles/iam.serviceAccountUser"
    members = [ "user:keithblixckauser@gmail.com" ]
  }
}

resource "google_service_account" "compute-sa" {
  account_id   = "compute-sa"
  display_name = "Compute Service Account"
}

resource "google_service_account_iam_policy" "gce-admin-iam" {
  service_account_id = google_service_account.compute-sa.name
  policy_data        = data.google_iam_policy.gce-admin.policy_data
}

###################################
# INSTANCE TEMPLATES
###################################

resource "google_compute_instance_template" "bastion-primary" {
  name_prefix    = "bastion-primary-" 
  project        =  var.project_id
  region         = var.default_region
  description    = "Bastion host in the primary subnet"
  tags           = [ "bastion-primary" ]
  machine_type   = "f1-micro"
  can_ip_forward = false
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  network_interface {
    network    = google_compute_network.kblix-cka-vpc.name
    subnetwork = google_compute_subnetwork.public-primary.name
    access_config {
    }
  }
  disk {
    source_image = "debian-cloud/debian-9"
    boot         = true
    auto_delete  = false
    mode         = "READ_WRITE"
    disk_size_gb = 100
  }
  lifecycle {
    create_before_destroy = true
  }
  metadata = {
    region         = var.default_region
    ssh-keys       = "${var.ssh_user}:${file(var.ssh_publickey_path)}"
    startup-script = "${file("./scripts/bastion.sh")}"
  }
  service_account {
    email  = google_service_account.compute-sa.email
    scopes = [ "cloud-platform" ]
  }
}

resource "google_compute_instance_template" "etcd-primary" {
  name_prefix    = "etcd-primary-" 
  project        =  var.project_id
  region         = var.default_region
  description    = "etcd host in the primary subnet"
  tags           = [ "etcd-primary" ]
  machine_type   = "n1-standard-2"
  can_ip_forward = false
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  network_interface {
    network    = google_compute_network.kblix-cka-vpc.name
    subnetwork = google_compute_subnetwork.public-primary.name
  }
  disk {
    source_image = "debian-cloud/debian-9"
    boot         = true
    auto_delete  = false
    mode         = "READ_WRITE"
    disk_size_gb = 200
  }
  lifecycle {
    create_before_destroy = true
  }
  metadata = {
    region         = var.default_region
    ssh-keys       = "${var.ssh_user}:${file(var.ssh_publickey_path)}"
    startup-script = "${file("./scripts/etcd.sh")}"
  }
  service_account {
    email  = google_service_account.compute-sa.email
    scopes = [ "cloud-platform" ]
  }
}

resource "google_compute_instance_template" "controlplane-primary" {
  name_prefix    = "controlplane-primary-" 
  project        =  var.project_id
  region         = var.default_region
  description    = "controlplane host in the primary subnet"
  tags           = [ "controlplane-primary" ]
  machine_type   = "n1-standard-4"
  can_ip_forward = false
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  network_interface {
    network    = google_compute_network.kblix-cka-vpc.name
    subnetwork = google_compute_subnetwork.public-primary.name
  }
  disk {
    source_image = "debian-cloud/debian-9"
    boot         = true
    auto_delete  = false
    mode         = "READ_WRITE"
    disk_size_gb = 100
  }
  lifecycle {
    create_before_destroy = true
  }
  metadata = {
    region         = var.default_region
    ssh-keys       = "${var.ssh_user}:${file(var.ssh_publickey_path)}"
    startup-script = "${file("./scripts/controlplane.sh")}"
  }
  service_account {
    email  = google_service_account.compute-sa.email
    scopes = [ "cloud-platform" ]
  }
}

resource "google_compute_instance_template" "workernodes-primary" {
  name_prefix    = "workernodes-primary-" 
  project        =  var.project_id
  region         = var.default_region
  description    = "workernode host in the primary subnet"
  tags           = [ "workernodes-primary" ]
  machine_type   = "e2-standard-16"
  can_ip_forward = false
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  network_interface {
    network    = google_compute_network.kblix-cka-vpc.name
    subnetwork = google_compute_subnetwork.public-primary.name
  }
  disk {
    source_image = "debian-cloud/debian-9"
    boot         = true
    auto_delete  = false
    mode         = "READ_WRITE"
    disk_size_gb = 100
  }
  lifecycle {
    create_before_destroy = true
  }
  metadata = {
    region         = var.default_region
    ssh-keys       = "${var.ssh_user}:${file(var.ssh_publickey_path)}"
    startup-script = "${file("./scripts/nodes.sh")}"
  }
  service_account {
    email  = google_service_account.compute-sa.email
    scopes = [ "cloud-platform" ]
  }
}

###################################
# NAT Gateway
###################################

resource "google_compute_router_nat" "nat" {
  name                               = "cloud-nat"
  router                             = google_compute_router.kblix-cka-router.name
  region                             = google_compute_router.kblix-cka-router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.etcd-primary.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  
  subnetwork {
    name                    = google_compute_subnetwork.controlplane-primary.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  
  subnetwork {
    name                    = google_compute_subnetwork.workernodes-primary.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
