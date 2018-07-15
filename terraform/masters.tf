resource "google_compute_instance" "kube_master" {
  count           = "${var.master_count}"
  name            = "${var.project}-master-${count.index}"
  zone            = "${var.gce_zone}"
  tags            = ["kthw", "${var.project}", "kubernetes", "controller", "apiserver"]
  machine_type    = "${var.master_machine_type}"
  can_ip_forward  = true

  network_interface {
    subnetwork = "${google_compute_subnetwork.kubernetes.self_link}"
    address = "${cidrhost(var.subnet_cidr, count.index+10)}"
    access_config {
      // Ephemeral IP
    }
  }

  boot_disk {
    initialize_params {
      # image = "debian-cloud/debian-9"
      image = "${var.bootDiskImage}"
      size  = "${var.bootDiskSize}"
      type  = "${var.bootDiskType}"
    }
  }

  labels {
    project = "${var.project}"
    environment = "${var.environment}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata_startup_script = "apt-get -q update && apt-get install -q -y nginx"
}
