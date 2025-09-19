#!/usr/bin/env bash
set -euo pipefail

# Определяем корень проекта (где лежат ansible/ и terraform/)
PROJECT_ROOT="$(dirname "$(realpath "$0")")"
INV_PATH="$PROJECT_ROOT/ansible/hosts.ini"

# Требуются yc и jq
command -v yc >/dev/null 2>&1 || { echo "yc CLI не найден. Установи/настрой yc."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq не найден. Установи jq."; exit 1; }

# Достаём адреса из YC по именам ВМ
# Внутренние IP
WEB_A_IP=$(yc compute instance get web-a --format json | jq -r '.network_interfaces[0].primary_v4_address.address')
WEB_B_IP=$(yc compute instance get web-b --format json | jq -r '.network_interfaces[0].primary_v4_address.address')
ELASTIC_IP=$(yc compute instance get elasticsearch --format json | jq -r '.network_interfaces[0].primary_v4_address.address')

# Внешний IP бастиона (one_to_one_nat.address)
BASTION_IP=$(yc compute instance get bastion --format json \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')

# Подстрахуемся, что всё нашли
for var in WEB_A_IP WEB_B_IP ELASTIC_IP BASTION_IP; do
  if [ -z "${!var:-}" ] || [ "${!var}" = "null" ]; then
    echo "Ошибка: переменная $var пустая. Проверь, что ВМ существуют и в правильной папке/облаке YC (yc config profile)."
    exit 1
  fi
done

# Yandex Cloud Ubuntu очень часто использует пользователя 'yc-user' на бастионе.
# Если у тебя точно 'ubuntu' — поменяй строку ниже на ubuntu.
BASTION_USER="ubuntu"

# Основной пользователь на веб/эластик нодах (обычно ubuntu)
ANSIBLE_USER="ubuntu"

# Генерируем hosts.ini
cat > "$INV_PATH" <<EOF
[web]
web-a ansible_host=$WEB_A_IP
web-b ansible_host=$WEB_B_IP

[elastic_nodes]
elastic1 ansible_host=$ELASTIC_IP

[bastion]
bastion ansible_host=$BASTION_IP ansible_user=$BASTION_USER

[all:vars]
ansible_user=$ANSIBLE_USER
ansible_ssh_private_key_file=~/.ssh/id_rsa
# ProxyJump через бастион (используем пользователя из группы [bastion])
ansible_ssh_common_args='-o ProxyJump=%(ansible_user)s@$BASTION_IP -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

echo "Готово: $INV_PATH"
echo "BASTION: $BASTION_IP ($BASTION_USER), WEB_A: $WEB_A_IP, WEB_B: $WEB_B_IP, ELASTIC: $ELASTIC_IP"
