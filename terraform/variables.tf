variable "gce_project_id"       { default = "project-id-123" }
variable "gce_credentials_json" { default = "/path/to/credentials.json"}

variable "gce_region"   { default = "us-east4" }
variable "gce_zone"     { default = "us-east4-c" }

variable "subnet_cidr"  { default = "10.4.0.0/24" }
variable "kube_cidr"    { default = "10.200.0.0/20" }
variable "local_cidr"   { default = "127.0.0.1/32" }

variable "master_count"         { default = 3 }
variable "master_machine_type"  { default = "n1-standard-1" }

variable "worker_count"         { default = 3 }
variable "worker_machine_type"  { default = "n1-standard-1" }

variable "bootDiskImage" { default = "ubuntu-os-cloud/ubuntu-1804-lts" }
variable "bootDiskType"  { default = "pd-ssd" }
variable "bootDiskSize"  { default = 10 }

variable "environment"  { default = "training" }
variable "project"      { default = "k8s" }
