provider "google" {
  credentials = "${file("${var.gce_credentials_json}")}"
  project     = "${var.gce_project_id}"
  region      = "${var.gce_region}"
  zone        = "${var.gce_zone}"
}

resource "google_compute_network" "kubernetes" {
  name                    = "${var.project}-network"
  auto_create_subnetworks = "false"
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "kubernetes" {
  name          = "${var.project}-subnet"
  ip_cidr_range = "${var.subnet_cidr}"
  network       = "${google_compute_network.kubernetes.self_link}"
}

resource "google_compute_firewall" "kube_external" {
  name          = "${var.project}-network-allow-defaults"
  network       = "${google_compute_network.kubernetes.name}"

  source_ranges = ["${var.local_cidr}"]
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }
}

resource "google_compute_firewall" "kube_internal" {
  name          = "${var.project}-network-allow-internal"
  network       = "${google_compute_network.kubernetes.name}"

  source_ranges = ["${var.subnet_cidr}", "${var.kube_cidr}"]
  allow { protocol = "icmp" }
  allow { protocol = "tcp" }
  allow { protocol = "udp" }
}

resource "google_compute_address" "kubelb" {
  name          = "${var.project}-lb-pubip"
  address_type  = "EXTERNAL"
}
