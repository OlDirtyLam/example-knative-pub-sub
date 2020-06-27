data "google_client_config" "provider" {}
provider "google-beta" {
  credentials = file(var.service_account_creds_file)

  project = var.project_id
  region  = var.region
  zone    = var.zone
}
provider "google" {
  credentials = file(var.service_account_creds_file)

  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_container_cluster" "ol_dirty_cluster" {
  provider = google-beta
  name               = var.cluster_name
  location           = var.zone

  min_master_version = "1.15.12-gke.2"

  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  network    = "default"
  subnetwork = "default"

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/14"
    services_ipv4_cidr_block = "/20"
  }

  workload_identity_config {
    identity_namespace = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    istio_config {
      disabled = false
    }
  }
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.cluster_name} --zone ${var.zone}"
  }
}

resource "google_container_node_pool" "ol_dirty_nodes" {
  name       = "ol-dirty-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.ol_dirty_cluster.name
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "n1-standard-2"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "google_pubsub_topic" "primary_topic" {
  name = "ol-dirty-topic"

  labels = {
    oldirtylabel = "hello_friend"
  }
}

# data "google_project" "ol_dirty_project" {
#   project_id = var.project_id
# }

# provider "kubernetes" {
#   load_config_file = false

#   host  = "https://${google_container_cluster.ol_dirty_cluster.endpoint}"
#   # token = data.google_service_account_access_token.service_user_token.access_token
#   token                  = data.google_client_config.provider.access_token
#   cluster_ca_certificate = base64decode(
#     google_container_cluster.ol_dirty_cluster.master_auth[0].cluster_ca_certificate,
#   )
# }
