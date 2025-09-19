# Уникальный суффикс для имён ALB-ресурсов (избегаем AlreadyExists)
resource "random_string" "sfx" {
  length  = 6
  upper   = false
  special = false
}

# Target group c приватными IP web-VM
resource "yandex_alb_target_group" "tg_web" {
  name = "${local.project}-tg-web-${random_string.sfx.result}"

  target {
    subnet_id  = yandex_vpc_subnet.private_a.id
    ip_address = yandex_compute_instance.web_a.network_interface[0].ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.private_b.id
    ip_address = yandex_compute_instance.web_b.network_interface[0].ip_address
  }
}

resource "yandex_alb_backend_group" "bg_web" {
  name = "${local.project}-bg-web-${random_string.sfx.result}"

  http_backend {
    name             = "web80"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_alb_target_group.tg_web.id]

    healthcheck {
      timeout  = "1s"
      interval = "3s"
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "http_router" {
  name = "${local.project}-http-router-${random_string.sfx.result}"
}

resource "yandex_alb_virtual_host" "vh_root" {
  name           = "root-${random_string.sfx.result}"
  http_router_id = yandex_alb_http_router.http_router.id

  route {
    name = "root"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.bg_web.id
      }
    }
  }
}

resource "yandex_alb_load_balancer" "alb" {
  name               = "${local.project}-alb-${random_string.sfx.result}"
  network_id         = local.vpc_id
  security_group_ids = [yandex_vpc_security_group.alb_sg.id]

  allocation_policy {
    location {
      zone_id   = var.zone_a
      subnet_id = yandex_vpc_subnet.public_a.id
    }
    location {
      zone_id   = var.zone_b
      subnet_id = yandex_vpc_subnet.public_b.id
    }
  }

  listener {
    name = "http"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.http_router.id
      }
    }
  }
}
