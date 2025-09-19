#################################
# VPC и маршрутизация
#################################

# VPC (создаём, только если var.vpc_id пуст)
resource "yandex_vpc_network" "vpc" {
  count = var.vpc_id == "" ? 1 : 0
  name  = "${local.project}-vpc"
}

# NAT Gateway (обязательно с shared_egress_gateway)
resource "yandex_vpc_gateway" "nat" {
  name = "${local.project}-nat"
  shared_egress_gateway {}
}

# Route Table для приватных подсетей
resource "yandex_vpc_route_table" "private_rt" {
  name       = "${local.project}-private-rt"
  network_id = local.vpc_id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

#################################
# Подсети
#################################

resource "yandex_vpc_subnet" "public_a" {
  name           = "${local.project}-public-a"
  zone           = var.zone_a
  network_id     = local.vpc_id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

resource "yandex_vpc_subnet" "public_b" {
  name           = "${local.project}-public-b"
  zone           = var.zone_b
  network_id     = local.vpc_id
  v4_cidr_blocks = ["10.10.1.0/24"]
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "${local.project}-private-a"
  zone           = var.zone_a
  network_id     = local.vpc_id
  v4_cidr_blocks = ["10.10.10.0/24"]
  route_table_id = yandex_vpc_route_table.private_rt.id
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "${local.project}-private-b"
  zone           = var.zone_b
  network_id     = local.vpc_id
  v4_cidr_blocks = ["10.10.11.0/24"]
  route_table_id = yandex_vpc_route_table.private_rt.id
}

#################################
# Security Groups
#################################

# Bastion
resource "yandex_vpc_security_group" "bastion_sg" {
  name        = "${local.project}-bastion-sg"
  network_id  = local.vpc_id
  description = "Allow SSH in; all egress"

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web servers
resource "yandex_vpc_security_group" "web_sg" {
  name        = "${local.project}-web-sg"
  description = "Web HTTP + SSH from bastion + Zabbix passive 10050 from Zabbix subnet"
  network_id  = local.vpc_id

  # HTTP отовсюду
  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH только с бастиона
  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion_sg.id
  }

  # Zabbix server -> agent (passive checks, zabbix_get) на 10050
  # РАЗРЫВАЕМ цикл: не ссылаемся на zabbix_sg, используем CIDR подсети, где стоит Zabbix (10.10.0.0/24)
  ingress {
    description    = "Zabbix server -> web:10050 (passive checks, zabbix_get)"
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["10.10.0.0/24"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Elasticsearch
resource "yandex_vpc_security_group" "es_sg" {
  name       = "${local.project}-es-sg"
  network_id = local.vpc_id

  ingress {
    description       = "ES HTTP 9200 from Kibana"
    protocol          = "TCP"
    port              = 9200
    security_group_id = yandex_vpc_security_group.kibana_sg.id
  }

  ingress {
    description       = "ES HTTP 9200 from Bastion"
    protocol          = "TCP"
    port              = 9200
    security_group_id = yandex_vpc_security_group.bastion_sg.id
  }

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion_sg.id
  }

  ingress {
    description    = "Beats 5044 (if used)"
    protocol       = "TCP"
    port           = 5044
    v4_cidr_blocks = ["10.10.0.0/16"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Zabbix
resource "yandex_vpc_security_group" "zabbix_sg" {
  name       = "${local.project}-zabbix-sg"
  network_id = local.vpc_id

  # web -> zabbix:10051 (active checks)
  # РАЗРЫВАЕМ цикл: разрешаем с внутренних сетей, где живут вебы
  ingress {
    description = "web -> zabbix:10051 (active checks)"
    protocol    = "TCP"
    port        = 10051
    v4_cidr_blocks = [
      "10.10.0.0/24",  # public_a (zabbix тоже здесь)
      "10.10.1.0/24",  # public_b
      "10.10.10.0/24", # private_a
      "10.10.11.0/24"  # private_b
    ]
  }

  # SSH откуда угодно (если нужно ограничить — замени на bastion_sg)
  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP UI Zabbix
  ingress {
    description    = "HTTP UI"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Kibana
resource "yandex_vpc_security_group" "kibana_sg" {
  name       = "${local.project}-kibana-sg"
  network_id = local.vpc_id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB SG (+ health checks)
resource "yandex_vpc_security_group" "alb_sg" {
  name       = "${local.project}-alb-sg"
  network_id = local.vpc_id

  ingress {
    description    = "HTTP public"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Разрешаем вход от систем health-check'ов ALB
  ingress {
    protocol          = "ANY"
    predefined_target = "loadbalancer_healthchecks"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
