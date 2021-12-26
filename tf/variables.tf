variable "project_id" {
  description = "Project ID where we are working."
  type        = string
  default     = "kolban-delete10"
}

variable "topic" {
  description = "Topic used for synchronization."
  type        = string
  default     = "mytopic"
}

variable "region" {
  description = "Region for our work."
  type        = string
  default     = "us-central1"
}
