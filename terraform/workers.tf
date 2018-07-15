resource "google_compute_instance" "kube_worker" {
  count           = "${var.worker_count}"
  name            = "${var.project}-worker-${count.index}"
  zone            = "${var.gce_zone}"
  tags            = ["kthw", "${var.project}", "kubernetes", "worker"]
  machine_type    = "${var.worker_machine_type}"
  can_ip_forward  = true

  network_interface {
    subnetwork = "${google_compute_subnetwork.kubernetes.self_link}"
    address = "${cidrhost(var.subnet_cidr, count.index+20)}"
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

  metadata {
    pod-cidr = "${cidrsubnet(var.kube_cidr, 4, count.index)}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata_startup_script = "apt-get -q update && apt-get install -q -y socat conntrack ipset"
}
