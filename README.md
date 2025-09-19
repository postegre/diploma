# YC Diploma Stack — Terraform + Ansible

## Что создаётся
- VPC с публичными и приватными подсетями в `ru-central1-a` и `ru-central1-b`
- NAT gateway и маршрутизация для приватных ВМ
- Bastion host (публичный IP)
- 2 веб-сервера (приватные, без внешнего IP) в разных зонах
- Application Load Balancer на 80 порт с health-check `/`
- Zabbix VM (публичная)
- Elasticsearch VM (приватная)
- Kibana VM (публичная)
- Security Groups с минимально необходимыми правилами
- Ежедневные снапшоты всех дисков с хранением 7 дней
- Ansible инвентори с FQDN `*.ru-central1.internal` и ProxyCommand через bastion

## Предпосылки
1. Установите Terraform и Ansible локально (или используйте bastion, на нём Ansible ставится cloud-init'ом).
2. Подготовьте SSH public key (например, `~/.ssh/id_ed25519.pub`).
3. Экспортируйте YC переменные окружения или укажите их в `terraform.tfvars` (токен лучше **не коммитить**):
   ```bash
   export YC_TOKEN=<token>
   export YC_CLOUD_ID=<cloud-id>
   export YC_FOLDER_ID=<folder-id>
   ```

## Деплой
```bash
cd terraform
cat > terraform.tfvars <<EOF
ssh_public_key = "${SSH_PUB_KEY:-$(cat ~/.ssh/id_ed25519.pub)}"
vm_user        = "ubuntu"
EOF

terraform init
terraform apply -auto-approve
```

После аплая посмотрите outputs — там будут `alb_public_ip`, `zabbix_url`, `kibana_url`, `bastion_public_ip` и путь к сгенерированному `ansible/hosts.ini`.

## Конфигурация с Ansible
```bash
cd ../ansible
# Использует ProxyCommand через bastion, FQDN вида web-a.ru-central1.internal
ansible-playbook site.yml
```

## Проверка
- Сайт: `curl -v http://<alb_public_ip>:80`
- Kibana: `http://<kibana_public_ip>:5601`
- Zabbix (UI): `http://<zabbix_public_ip>/`
  - Первый запуск: веб-инсталлятор Zabbix подскажет шаги настройки (по умолчанию MariaDB размещается на той же ВМ).
  - Дальше добавьте хосты `web-a` и `web-b` — агент уже установится ролью `agent`.

## Примечания
- Все ВМ помечены как прерываемые (preemptible). Перед сдачей замените на постоянные, убрав `scheduling_policy { preemptible = true }` и пересоздав ВМ.
- Для HTTPS можно позже прикрутить Yandex Certificate Manager и перевести ALB на 443.
- Инвентори не содержит IP — только FQDN `*.ru-central1.internal`, как требуется.
