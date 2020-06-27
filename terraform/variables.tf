variable "project_id" {
    type = string
}

variable "region" {
    type = string
    default = "us-central1"
}

variable "zone" {
    type = string
    default = "us-central1-c"
}

variable "cluster_name" {
  type = string
  default = "ol-dirty-k8"
}

variable "service_account_creds_file" {
  type = string
  default = "knative-example-sa-creds.json"
}
