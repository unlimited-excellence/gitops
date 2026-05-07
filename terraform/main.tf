provider "google" {
  region = var.region
}

# Project Creation
resource "google_project" "shared" {
  name            = var.project_name
  project_id      = var.project_id
  billing_account = var.billing_account
  org_id          = var.org_id
}

# Enable Services
resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com"
  ])
  project = google_project.shared.project_id
  service = each.key

  disable_on_destroy = false
}

# Network
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  project                 = google_project.shared.project_id
  auto_create_subnetworks = false
  depends_on              = [google_project_service.services]
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.cluster_name}-subnet"
  project                  = google_project.shared.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.0.0.0/16"
  private_ip_google_access = true
}

# Cloud NAT (needed for private nodes to access internet)
resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  project = google_project.shared.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  project                            = google_project.shared.project_id
  region                             = var.region
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# GKE Autopilot Cluster
resource "google_container_cluster" "autopilot" {
  name     = var.cluster_name
  location = var.region
  project  = google_project.shared.project_id

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  enable_autopilot = true

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep public endpoint for easy access
  }

  # Wait for services and networking to be ready
  depends_on = [
    google_project_service.services,
    google_compute_router_nat.nat
  ]
}

# Provider configuration for Kubernetes and Helm
# These use the output of the GKE cluster resource
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.autopilot.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.autopilot.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate)
  }

  # Isolate helm cache to avoid issues with local helm state (e.g. 'likespro' error)
  repository_config_path = "${path.module}/.helm/repositories.yaml"
  repository_cache       = "${path.module}/.helm/repository"
}

# ArgoCD Installation
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.7" # Use a stable version

  set {
    name  = "configs.repositories.gitops.url"
    value = "https://github.com/unlimited-excellence/gitops.git"
  }

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.additionalApplications[0].name"
    value = "root-app"
  }

  set {
    name  = "server.additionalApplications[0].namespace"
    value = "argocd"
  }

  set {
    name  = "server.additionalApplications[0].spec.project"
    value = "default"
  }

  set {
    name  = "server.additionalApplications[0].spec.source.repoURL"
    value = "https://github.com/unlimited-excellence/gitops.git"
  }

  set {
    name  = "server.additionalApplications[0].spec.source.path"
    value = "manifests"
  }

  set {
    name  = "server.additionalApplications[0].spec.source.targetRevision"
    value = "HEAD"
  }

  set {
    name  = "server.additionalApplications[0].spec.destination.server"
    value = "https://kubernetes.default.svc"
  }

  set {
    name  = "server.additionalApplications[0].spec.destination.namespace"
    value = "default"
  }

  set {
    name  = "server.additionalApplications[0].spec.syncPolicy.automated.prune"
    value = "true"
  }

  set {
    name  = "server.additionalApplications[0].spec.syncPolicy.automated.selfHeal"
    value = "true"
  }

  depends_on = [google_container_cluster.autopilot]
}
