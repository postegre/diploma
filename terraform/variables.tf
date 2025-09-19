variable "yc_token" {
  description = "Yandex Cloud IAM/OAuth token (leave empty to use env var)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloud_id" {
  description = "YC Cloud ID (leave empty to use env var)"
  type        = string
  default     = ""
}

variable "folder_id" {
  description = "YC Folder ID (leave empty to use env var)"
  type        = string
  default     = ""
}

variable "default_zone" {
  type    = string
  default = "ru-central1-a"
}

variable "zone_a" {
  type    = string
  default = "ru-central1-a"
}

variable "zone_b" {
  type    = string
  default = "ru-central1-b"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "vm_user" {
  description = "Default VM user to create"
  type        = string
  default     = "ubuntu"
}

variable "core_fraction" {
  type    = number
  default = 20
}

variable "web_instance_type" {
  description = "vCPU and RAM for web nodes"
  type        = object({ cores = number, memory = number })
  default     = { cores = 2, memory = 2 }
}

variable "misc_instance_type" {
  description = "vCPU and RAM for Zabbix/Kibana/ES/Bastion"
  type        = object({ cores = number, memory = number })
  default     = { cores = 2, memory = 4 }
}

variable "disk_size_gb" {
  type    = number
  default = 10
}

# NEW: если задан, будем использовать существующий VPC и не создавать новый
variable "vpc_id" {
  description = "Existing VPC network ID to reuse (optional). If empty, a new VPC will be created."
  type        = string
  default     = ""
}
