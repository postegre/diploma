########################################
# ALB: target group -> backend group -> router/vhost -> LB
########################################

# Target Group: берём фактические subnet_id и ip_address у ВМ
resource "yandex_alb_target_group" "web_tg" {
  name = "${local.project}-web-tg"

  target {
    subnet_id  = yandex_compute_instance.web_a.network_interface[0].subnet_id
    ip_address = yandex_compute_instance.web_a.network_interface[0].ip_address
  }

  target {
    subnet_id  = yandex_compute_instance.web_b.network_interface[0].subnet_id
    ip_address = yandex_compute_instance.web_b.network_interface[0].ip_address
  }
}

# Backend Group: один http-бэкенд на порт 80 с healthcheck
resource "yandex_alb_backend_group" "web_bg" {
  name = "${local.project}-web-bg"

  http_backend {
    name             = "web-80"
    port             = 80
    target_group_ids = [yandex_alb_target_group.web_tg.id]
    load_balancing_config {
      panic_threshold = 50
    }
    healthcheck {
      timeout  = "2s"
      interval = "5s"
      healthy_threshold   = 2
      unhealthy_threshold = 3
      http_healthcheck {
        path = "/"
      }
    }
  }
}

# HTTP Router
resource "yandex_alb_http_router" "web_router" {
  name = "${local.project}-web-router"
}

# Virtual Host + маршрут на backend group
resource "yandex_alb_virtual_host" "web_vhost" {
  name          = "${local.project}-web-vhost"
  http_router_id = yandex_alb_http_router.web_router.id

  route {
    name = "all-to-web"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_bg.id
      }
    }
  }
}

# Сам ALB с публичным IP и листенером на 80
resource "yandex_alb_load_balancer" "web_alb" {
  name       = "${local.project}-web-alb"
  network_id = local.vpc_id

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
    name = "http-80"
    endpoint {
      address {
        external_ipv4_address {} # выдаст публичный адрес
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id
      }
    }
  }
}

# Удобные выводы
output "alb_external_ip" {
  description = "Публичный IPv4 ALB"
  value       = try(yandex_alb_load_balancer.web_alb.listener[0].endpoint[0].address[0].external_ipv4_address[0].address, null)
}

output "alb_url" {
  description = "http://<ALB_IP>/"
  value       = (
    try(yandex_alb_load_balancer.web_alb.listener[0].endpoint[0].address[0].external_ipv4_address[0].address, null) == null
    ? null
    : "http://${yandex_alb_load_balancer.web_alb.listener[0].endpoint[0].address[0].external_ipv4_address[0].address}/"
  )
}
