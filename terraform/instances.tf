# -------- Bastion --------
resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  hostname    = "bastion"
  zone        = var.zone_a
  platform_id = "standard-v3"
  labels      = local.labels

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu2204.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }

  metadata = {
    # оставляем и стандартный канал доставки ключей…
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    # …и принудительно кладём ключ в authorized_keys через cloud-init
    user-data = <<-EOT
      #cloud-config
      package_update: true
      packages:
        - python3
        - python3-pip
        - git
        - ansible
      users:
        - name: ubuntu
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: sudo
          shell: /bin/bash
          ssh_authorized_keys:
            - ${var.ssh_public_key}
      runcmd:
        - 'echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config && systemctl restart ssh'
    EOT
  }

  scheduling_policy {
    preemptible = true
  }
}

# -------- Web A --------
resource "yandex_compute_instance" "web_a" {
  name        = "web-a"
  hostname    = "web-a"
  zone        = var.zone_a
  platform_id = "standard-v3"
  labels      = local.labels

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu2204.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = true
  }
}

# -------- Web B --------
resource "yandex_compute_instance" "web_b" {
  name        = "web-b"
  hostname    = "web-b"
  zone        = var.zone_b
  platform_id = "standard-v3"
  labels      = local.labels

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu2204.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = true
  }
}

# -------- Zabbix --------
resource "yandex_compute_instance" "zabbix" {
  name        = "zabbix"
  hostname    = "zabbix"
  zone        = var.zone_a
  platform_id = "standard-v3"
  labels      = local.labels

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu2204.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.zabbix_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = true
  }
}

# -------- Elasticsearch --------
resource "yandex_compute_instance" "elasticsearch" {
  name        = "elasticsearch"
  hostname    = "elasticsearch"
  zone        = var.zone_a
  platform_id = "standard-v3"
  labels      = local.labels

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu2204.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.es_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = true
  }
}

# -------- Kibana --------
resource "yandex_compute_instance" "kibana" {
  name        = "kibana"
  hostname    = "kibana"
  zone        = var.zone_b
  platform_id = "standard-v3"
  labels      = local.labels

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu2204.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_b.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.kibana_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = true
  }
}
