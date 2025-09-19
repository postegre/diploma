terraform {
  required_version = ">= 1.5.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.116.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "yandex" {
  # Если var-поля пустые, провайдер возьмёт значения из окружения:
  # YC_TOKEN или YC_SERVICE_ACCOUNT_KEY_FILE, а также YC_CLOUD_ID/YC_FOLDER_ID
  token     = var.yc_token != "" ? var.yc_token : null
  cloud_id  = var.cloud_id != "" ? var.cloud_id : null
  folder_id = var.folder_id != "" ? var.folder_id : null
  zone      = var.default_zone
}
