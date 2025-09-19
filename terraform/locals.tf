locals {
  project = "yc-diploma"
  labels = {
    project = local.project
  }

  # Если var.vpc_id задан — используем его.
  # Если нет — возьмём id созданного ресурса yandex_vpc_network.vpc[0].
  vpc_id = var.vpc_id != "" ? var.vpc_id : try(yandex_vpc_network.vpc[0].id, "")
}

data "yandex_compute_image" "ubuntu2204" {
  family = "ubuntu-2204-lts"
}
