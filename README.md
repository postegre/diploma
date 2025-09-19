Diploma: HA Web + Monitoring + Logs + Backups (Yandex Cloud, Terraform + Ansible)
TL;DR

Инфраструктура для отказоустойчивого сайта с базовым мониторингом, сбором логов и резервным копированием. Всё описано кодом (Terraform + Ansible), секреты в git не хранятся.
Реализованы: сеть, ВМ, балансировка, базовый веб, агентский мониторинг, бэкапы, каркас логирования.
Ограничения: из-за сетевых/санкционных ограничений и офлайн-пакетов логирование на Elastic/Kibana доведено до MVP/partial, см. раздел «Что не удалось завершить».

Архитектура (MVP)

Сеть: VPC, приватные/публичные подсети, SG, (опционально) Bastion/NAT.

Балансировка: L4/L7 LB с health-check, раздаёт трафик на 2× web-VM (Nginx).

Мониторинг: Zabbix-agent на хостах (каркас Zabbix-server/Prometheus присутствует в коде).

Логи: Filebeat на хостах → Elastic (single-node)/Kibana (каркас; см. ограничения ниже).

Бэкапы: snapshot-политика (ночные слепки, ретеншн ~7 дней; параметры — в переменных).

Безопасность: SSH по ключам, токены/секреты вне git, базовые firewall-правила.

Структура репозитория
.
├─ ansible/                 # роли и плейбуки (web, zabbix-agent, filebeat, elastic/kibana и т.д.)
├─ terraform/               # Terraform для Yandex Cloud (VPC, LB, ВМ, SG, снапшоты и пр.)
├─ gen_inventory.sh         # генерация Ansible-инвентаря из Terraform/YC
├─ README.md                # этот файл

Предварительные требования

Ubuntu 22.04+/macOS, bash.

Terraform ≥ 1.5, Ansible ≥ 2.15.

Доступ в Yandex Cloud (service account + ключи вне git).

ssh-доступ по ключам.

(Опционально) git-lfs, если будете хранить крупные офлайн-пакеты.

Настройка переменных

В terraform/ создайте terraform.tfvars (секреты в git не коммитим):

cloud_id      = "..."
folder_id     = "..."
sa_key_file   = "/path/to/authorized_key.json"   # вне репозитория
zone          = "ru-central1-a"
# ... остальные переменные модуля/проекта


Для Ansible — group_vars/host_vars по месту. Инвентарь:

./gen_inventory.sh > ansible/hosts.ini

Развёртывание
# 1) Terraform
cd terraform
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve

# 2) Инвентарь для Ansible
cd ..
./gen_inventory.sh > ansible/hosts.ini

# 3) Конфигурация ВМ
ansible -i ansible/hosts.ini all -m ping
ansible-playbook -i ansible/hosts.ini ansible/site.yml

Проверка работоспособности

Веб:

Откройте http://<LOAD_BALANCER_IP>/ — должна отдаваться страница с двух web-узлов по очереди (проверить заголовок/метку узла).

Health-checks LB — «healthy».

Мониторинг:

На ВМ: systemctl status zabbix-agent → active.

(Если поднимали Zabbix-server/Prometheus) — доступен веб-интерфейс/метрики.

Логи (MVP):

filebeat test output — должен подтверждать доступность цели или выводим в локальный файл/стаб (см. ограничения).

Бэкапы:

В YC/через CLI видна snapshot-политика и ночные слепки дисков.

Что сделано 

Описан кодом полный каркас: сеть, балансировщик, ВМ, security-группы.

Веб-уровень: 2×web-узла за LB (Nginx), health-check настроен.

Мониторинг на узлах: zabbix-agent (плейбуки/роли присутствуют, сервис активируется).

Логирование: filebeat установлен и нацелен на Elastic (single-node) — каркас имеется, конфиги параметризованы.

Бэкап-стратегия: snapshot policy (ежедневно, ретеншн ~7 дней — регулируется переменными).

Безопасность: доступ по SSH-ключам, токены/секреты не хранятся в git; .gitignore исключает .terraform/, состояния, логи и крупные артефакты.

Скрипт для генерации инвентаря: gen_inventory.sh (ускоряет связку TF → Ansible).

Что не удалось довести до конца 

Полная обвязка ELK (Elastic/Kibana) онлайн:
Из-за сетевых/санкционных ограничений скачивание репозиториев/пакетов и доступ web-узлов до :9200 периодически падает (timeouts). Оффлайн-установка через .deb размером >100 MB блокируется GitHub (лимит), LFS не использовался, чтобы не увеличивать вес/квоты.

Единый дашборд логов в Kibana:
Каркас есть, но финальная связность (filebeat → elastic → kibana index patterns) не зафиксирована как стабильно воспроизводимая в онлайне.

Автоконфиг для Zabbix-server/Frontend:
Агентский слой готов; серверная часть/фронт могут требовать ручной донастройки (DB, веб-морда) либо альтернативу (Prometheus stack).

Основные трудности и как решались

Санкции/сеть: недоступность внешних репозиториев и провайдеров → использовались офлайн-пакеты/зеркала; часть задач вынесена в роли, но крупные .deb не храним в git (см. ниже).

GitHub лимиты: при первом пуше попали бинарники >100 MB → репозиторий очищен, добавлен .gitignore; крупные артефакты исключены.

Filebeat/Elastic: конфиги и маршрут до :9200 ловили timeouts (в приватных подсетях + SG). Добавлены переменные и проверки filebeat test output, чтобы быстро диагностировать сетевой/ACL-барьер.

Nginx/Zabbix-frontend: на ранних итерациях отдавалась стандартная страница Nginx — роли приведены к явному деплою веб-контента/вирт-хостов; Zabbix-frontend оставлен как опциональный модуль.

Рекомендации по повторяемости (если будете проверять)

Артефакты: не хранить .deb в git. В Ansible использовать get_url с внутреннего зеркала (S3/Object Storage/локальный nginx) + контроль SHA256.

Сеть: проверить маршруты/SG для web → elastic:9200 и доступ LB снаружи.

Заменяемость логов: если Elastic недоступен, временно направлять Filebeat в локальный файл/Vector/JSON-приёмник, чтобы показать поток логов и формат.

Secrets: держать terraform.tfvars/ключи вне репозитория; приложить только _example.tfvars.

Как переключить логи на офлайн-пакеты/зеркало (пример ansible)
- name: Download Elasticsearch deb from internal mirror
  get_url:
    url: "https://<internal-mirror>/elasticsearch-8.14.3-amd64.deb"
    dest: "/tmp/elasticsearch-8.14.3-amd64.deb"
    mode: "0644"

- name: Install Elasticsearch
  apt:
    deb: "/tmp/elasticsearch-8.14.3-amd64.deb"


Аналогично для Kibana/Filebeat. В prod-версии — репозитории/подписи, systemd-unit overrides, health-checks, алерты.

Уничтожение инфраструктуры
cd terraform
terraform destroy -var-file=terraform.tfvars -auto-approve

Планы на доработку (roadmap)

Перенос логирования в устойчивую схему: либо ELK с внутренним зеркалом, либо Loki+Promtail/Vector.

Полноценный мониторинг: автодискавери хостов, базовые алерты (CPU/RAM/Disk/Service) в Slack/Telegram.

Ужесточение безопасности: Bastion jump host по умолчанию, закрытые SG, отключение паролей, CIS-профили.

CI/CD: terraform fmt/validate, ansible-lint, Molecule-тесты ролей, pre-commit.

Бэкапы БД с PITR (если появится stateful-сервис), ретеншн/policy в переменные окружения.

Примечание по безопасности

Репозиторий не содержит токенов/секретов. Все чувствительные значения задаются через локальные файлы (terraform.tfvars) или переменные окружения и не коммитятся.

