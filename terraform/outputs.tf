output "project_id" {
  value       = google_project.shared.project_id
  description = "The ID of the created project"
}

output "cluster_name" {
  value       = google_container_cluster.autopilot.name
  description = "The name of the GKE cluster"
}

output "cluster_endpoint" {
  value       = google_container_cluster.autopilot.endpoint
  description = "The endpoint of the GKE cluster"
}

output "argocd_namespace" {
  value       = helm_release.argocd.namespace
  description = "The namespace where ArgoCD is installed"
}
