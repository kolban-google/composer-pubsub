# Creates
# Enables API Services
# - composer, pubsub, artifactregistry, compute
# Creates a composer environment
# Creates a service account for composer
# Creates a repository
#
// Configure the Google Cloud provider
provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

resource "google_project_service" "enable-composer" {
  service = "composer.googleapis.com"
}

resource "google_project_service" "enable-pubsub" {
  service = "pubsub.googleapis.com"
}

resource "google_project_service" "enable-artifactregistry" {
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "enable-compute" {
  service = "compute.googleapis.com"
}

resource "google_composer_environment" "test" {
  name   = "test"
  region = "us-central1"
  config {
    software_config {
      image_version = "composer-1.17.7-airflow-2.1.4"
      env_variables = {
          GCP_PROJECTID = var.project_id
          GCP_TOPIC = var.topic
      }
    }
    node_config {
      service_account = google_service_account.composer-sa.email
    }
  }
}

resource "google_service_account" "composer-sa" {
    account_id = "composer-sa"
}

resource "google_artifact_registry_repository" "repo" {
  provider = google-beta
  location = var.region
  repository_id = "my-repository"
  description = "example docker repository"
  format = "DOCKER"
}
