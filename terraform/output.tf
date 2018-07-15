output "master_ips" {
    value = "${google_compute_instance.kube_master.*.network_interface.0.address}"
}
output "master_pubips" {
    value = "${google_compute_instance.kube_master.*.network_interface.0.access_config.0.assigned_nat_ip}"
    depends_on = ["google_compute_instance.kube_master"]
}

output "worker_ips" {
    value = "${google_compute_instance.kube_worker.*.network_interface.0.address}"
}
output "worker_pubips" {
    value = "${google_compute_instance.kube_worker.*.network_interface.0.access_config.0.assigned_nat_ip}"
    depends_on = ["google_compute_instance.kube_worker"]
}
