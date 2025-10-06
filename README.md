Дипломный проект: инфраструктура в Яндекс Облаке с Terraform + Ansible
(Nginx веб-узлы, Elasticsearch + Kibana, Zabbix, сбор логов Filebeat)

1) О чём проект и что сделаноо

Цель - описать и развернуть минимально жизнеспособный стек в Яндекс Облаке средствами IaC:

Сеть VPC, подсети, Security Groups, публичный bastion

Веб-уровень: 2 ВМ с Ubuntu + Nginx (+ Filebeat для логов)

Логирование: 1 ВМ с Elasticsearch + Kibana

Мониторинг: Zabbix-server

Автоматизация конфигурации — Ansible с ролями и переменными групп

SSH-доступ на внутренние хосты через ProxyJump (bastion)

Единый плейбук и теги: можно применять частично (только elastic/kibana или только filebeat и т.п.)

Чистка секретов и безопасные шаблоны конфигов (без захардкоженных паролей в гите)

2) Архитектура и компоненты
2.1. Топология

bastion (публичный IP) — единственная точка входа по SSH

elastic1 (внутренний IP) — Elasticsearch 8.x + Kibana 8.x

web-a, web-b (внутренние IP) — Nginx, Filebeat, опционально Zabbix-agent

zabbix (опционально отдельная ВМ) — Zabbix server + frontend + Postgres

Вся внутренняя связь — по приватным адресам. Filebeat на веб-узлах отправляет логи в Elasticsearch; Kibana — визуализация; Zabbix следит за доступностью сервисов

2.2. Безопасность

Доступ к приватным ВМ только через bastion (ProxyJump)

Security Groups открывают наружу только 22/tcp на bastion и 80/tcp (если нужно опубликовать фронтенд)

Пароли в шаблонах не коммитятся: все чувствительные значения — через переменные, Ansible Vault (при необходимости) или генерируются на лету

3) Репозиторий: структура
.
├── terraform/                 # описание сети и ВМ в Яндекс Облаке
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars.example
└── ansible/
    ├── ansible.cfg
    ├── hosts.ini              # inventory (группы: bastion, elastic_nodes, web, zabbix)
    ├── site.yml               # корневой плейбук
    ├── group_vars/
    │   ├── all.yml            # bastion_host + общие SSH-аргументы
    │   ├── elastic_nodes.yml  # настройки Elasticsearch/Kibana + filebeat для elastic1
    │   ├── web.yml            # nginx, filebeat для web-узлов
    │   └── zabbix.yml         # параметры Zabbix API/БД (учебные)
    └── roles/
        ├── nginx/
        ├── elasticsearch/
        ├── kibana/
        ├── filebeat/
        └── zabbix/


Ключевая идея: всё управляется переменными в group_vars, а доступ через bastion — одной строкой в all.yml

4) Переменные (главные)
4.1. group_vars/all.yml (пример)
ansible_user: ubuntu
ansible_ssh_private_key_file: /home/USER/.ssh/id_rsa

# Сквозной ProxyJump для всех внутренних хостов:
ssh_common_args: >-
  -o ProxyJump={{ ansible_user }}@{{ bastion_host }}
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ServerAliveInterval=60
  -o ServerAliveCountMax=3

4.2. group_vars/web.yml (пример)
zabbix_server_ip: 10.10.0.24
zabbix_agent_server: "{{ zabbix_server_ip }}"
zabbix_agent_serveractive: "{{ zabbix_server_ip }}"

ansible_ssh_common_args: "{{ ssh_common_args }}"

# Filebeat на web → в Elasticsearch на elastic1:
filebeat_elasticsearch_url: "http://10.10.0.5:9200"
filebeat_kibana_url: "10.10.0.5:5601"
filebeat_setup_enabled: true
filebeat_enable_nginx_module: true

4.3. group_vars/elastic_nodes.yml
elastic_cluster_name: yc-diploma
elastic_network_host: "0.0.0.0"
elastic_http_port: 9200
elastic_discovery_type: "single-node"
elastic_security_enabled: false

# Filebeat локально на elastic1:
filebeat_elasticsearch_url: "http://127.0.0.1:9200"
filebeat_kibana_url: "127.0.0.1:5601"
filebeat_setup_enabled: true
filebeat_enable_nginx_module: false

ansible_ssh_common_args: "{{ ssh_common_args }}"

4.4. group_vars/zabbix.yml (учебный пример)
zbx_api_url: "http://localhost/zabbix/api_jsonrpc.php"
zbx_api_user: "Admin"
zbx_api_password: "zabbix"
zbx_autoreg_group: "Linux servers"

5) Развёртывание: как это делалось
5.1. Terraform (суммарно)

terraform/terraform.tfvars (cloud_id, folder_id, подсети, публичный ключ, размеры ВМ).

terraform init && terraform plan && terraform apply

В выходных переменных — IP bastion и внутренних узлов

5.2. Ansible: одна строка для ProxyJump

В group_vars/all.yml bastion_host фактический публичный IP

Inventory ansible/hosts.ini указывает внутренние IP и не хранит опасных форматов %() — всё проксируется за счёт ansible_ssh_common_args из group_vars

5.3. Порядок применения плейбуков
# Проверка связи:
ansible -i hosts.ini all -m ping

# 1) Elasticsearch + Kibana на elastic_nodes
ansible-playbook -i hosts.ini site.yml -l elastic_nodes -t elasticsearch,kibana

# 2) Веб-узлы: nginx + filebeat
ansible-playbook -i hosts.ini site.yml -l web -t nginx,filebeat,filebeat_config,filebeat_setup

# 3) Zabbix (если выбран)
ansible-playbook -i hosts.ini site.yml -l zabbix -t zabbix

6) Проверка работоспособности
6.1. Kibana жива
ansible -i hosts.ini elastic_nodes -m uri \
  -a 'url=http://127.0.0.1:5601/api/status status_code=200,503 return_content=yes' -o


Ожидаем overall.level: "available".

6.2. Filebeat шлёт логи
# На web: тест коннекта к ES
ansible -i hosts.ini web -b -a 'filebeat test output || true'

# На elastic1: появились индексы/датастримы
ansible -i hosts.ini elastic_nodes -m uri \
  -a 'url=http://127.0.0.1:9200/_cat/indices/filebeat*?v return_content=yes'

ansible -i hosts.ini elastic_nodes -m uri \
  -a 'url=http://127.0.0.1:9200/_data_stream?filter_path=data_streams.name,data_streams.indices.index_name&pretty return_content=yes'

6.3. Nginx отвечает
ansible -i hosts.ini web -a 'curl -I http://127.0.0.1/ || true'

6.4. Zabbix UI

Открывается login-страница, логин/пароль: Admin/zabbix

7) Типичные проблемы и как решались

SSH «vdollar_percent_expand…»
Причина: в hosts.ini/шаблонах попали строки вида %(ansible_user)s
Решение: убрать форматные %(), вынести ProxyJump в group_vars/all.yml (ssh_common_args)

Сломанный known_hosts при смене IP
При смене bastion IP — конфликт отпечатков ключа
Решение: очистка строки с этим IP из ~/.ssh/known_hosts (или ssh-keygen -R <ip>), затем повторное подключение

apt 403 InRelease для репо Elastic
Решения:

использовать локальные .deb из roles/*/files/


Filebeat на web смотрит в 127.0.0.1:9200
Это не elastic1 → таймаут
Решение: на web всегда http://<внутр. ip elastic1>:9200. Проверить group_vars/web.yml.


8) Безопасность и отсутствие секретов в гите

Перед коммитом выполнялись проверки:

# закрытые ключи
grep -RIl --binary-files=without-match -E 'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY' \
  --exclude-dir=.git --exclude-dir=collections --exclude='*.deb' --exclude-dir='roles/*/files' .

# логины с паролями в URL
grep -RIn --binary-files=without-match -E '[a-z]+://[^/@ ]+:[^/@ ]+@' \
  --exclude-dir=.git --exclude-dir=collections --exclude='*.deb' --exclude-dir='roles/*/files' .

# подозрительные слова
grep -RIn --binary-files=without-match -i -E '(password|passwd|pwd|secret|token|api[_-]?key|bearer\s+[A-Za-z0-9._-]+)' \
  --exclude-dir=.git --exclude-dir=collections --exclude='*.deb' --exclude-dir='roles/*/files' .


9) Как удалить инфраструктуру
# в каталоге terraform/
terraform destroy

10) Ограничения и развитие

Кластер Elasticsearch — single-node для диплома . Для прод — минимум 3 мастера и дисковая отказоустойчивость

Без включённой security в Elastic (xpack): в проде — только с TLS/учётками

Zabbix и Postgres можно разделить по ВМ, добавить резервные копии

Filebeat собирал только Nginx-логи. Можно подключить system/auth/journal, парсинг по ECS

1) Итог

Проект показывает:

Умение описывать инфраструктуру кодом (Terraform + Ansible).

Разделение ролей и параметров (group_vars), единый ProxyJump для приватной топологии.

Сбор и визуализацию логов (Filebeat → Elasticsearch → Kibana).

Базовый мониторинг (Zabbix).

Аккуратную работу с секретами (проверки и отсутствие приватных данных в репозитории).
