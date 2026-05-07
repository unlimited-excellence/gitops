variable "project_id" {
  description = "The ID of the project to create"
  type        = string
  default     = "shared-project-unique-id"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "shared"
}

variable "billing_account" {
  description = "The billing account ID to associate with the project"
  type        = string
}

variable "org_id" {
  description = "The organization ID (optional)"
  type        = string
  default     = null
}

variable "region" {
  description = "The region to deploy the GKE cluster"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "shared-autopilot-cluster"
}
