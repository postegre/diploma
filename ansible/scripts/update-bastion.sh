#!/usr/bin/env bash
set -Eeuo pipefail

# --- Параметры (можно переопределить переменными окружения) ---
BASTION_NAME="${BASTION_NAME:-bastion}"
PUB_KEY_PATH="${PUB_KEY_PATH:-$HOME/.ssh/id_rsa.pub}"
PRIV_KEY_PATH="${PRIV_KEY_PATH:-$HOME/.ssh/id_rsa}"
ANSIBLE_DIR="${ANSIBLE_DIR:-$PWD}"   # запусти из ansible/ или укажи путь
ANSIBLE_VARS_FILE="${ANSIBLE_VARS_FILE:-$ANSIBLE_DIR/group_vars/all.yml}"

# --- Проверки окружения ---
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERR: '$1' not found in PATH"; exit 1; }; }
need yc; need jq; need ssh-keygen; need ssh-keyscan

if [[ ! -f "$PUB_KEY_PATH" ]]; then
  echo "SSH public key not found at $PUB_KEY_PATH"
  echo "Generating a new keypair..."
  ssh-keygen -t rsa -b 4096 -N "" -f "${PRIV_KEY_PATH}"
fi

# --- Находим ID бастиона по имени ---
echo ">> Resolving bastion instance by name: $BASTION_NAME"
BASTION_ID="$(yc compute instance list --format json \
  | jq -r --arg n "$BASTION_NAME" '.[] | select(.name==$n) | .id' | head -n1)"

if [[ -z "${BASTION_ID}" || "${BASTION_ID}" == "null" ]]; then
  echo "ERR: Bastion instance '$BASTION_NAME' not found in current folder."
  exit 1
fi
echo "   Bastion ID: $BASTION_ID"

# --- Берём актуальный публичный IP из YC (не из terraform state) ---
BASTION_IP="$(yc compute instance get --id "$BASTION_ID" --format json \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')"

if [[ -z "${BASTION_IP}" || "${BASTION_IP}" == "null" ]]; then
  echo "ERR: Bastion has no public IP (one_to_one_nat.address is empty)."
  exit 1
fi
echo "   Bastion IP: $BASTION_IP"

# --- Заливаем SSH ключ в метаданные ВМ ---
TMP_KEYS="$(mktemp)"
printf "ubuntu:%s\n" "$(cat "$PUB_KEY_PATH")" > "$TMP_KEYS"
echo ">> Updating instance metadata ssh-keys..."
yc compute instance update --id "$BASTION_ID" --metadata-from-file "ssh-keys=$TMP_KEYS" >/dev/null
rm -f "$TMP_KEYS"
echo "   Metadata updated."

# --- Чистим и обновляем known_hosts ---
echo ">> Refreshing ~/.ssh/known_hosts for $BASTION_IP and bastion hostname"
# Удалим по IP и по fqdn (если есть)
ssh-keygen -R "$BASTION_IP" >/dev/null 2>&1 || true
ssh-keygen -R "bastion.ru-central1.internal" >/dev/null 2>&1 || true
# Добавим новый ключ
ssh-keyscan -t ed25519 "$BASTION_IP" >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
echo "   known_hosts updated."

# --- Обновим ProxyJump для Ansible, если есть group_vars/all.yml ---
if [[ -f "$ANSIBLE_VARS_FILE" ]]; then
  echo ">> Updating $ANSIBLE_VARS_FILE (ProxyJump -> $BASTION_IP)"
  mkdir -p "$(dirname "$ANSIBLE_VARS_FILE")"
  cp -a "$ANSIBLE_VARS_FILE" "${ANSIBLE_VARS_FILE}.bak.$(date +%s)" || true
  cat > "$ANSIBLE_VARS_FILE" <<YAML
ansible_user: ubuntu
ansible_ssh_private_key_file: ${PRIV_KEY_PATH}
ansible_ssh_common_args: "-o ProxyJump=ubuntu@${BASTION_IP}"
YAML
  echo "   Ansible vars updated."
else
  echo ">> Skipping Ansible vars (file not found): $ANSIBLE_VARS_FILE"
fi

# --- Быстрая проверка SSH на бастион ---
echo ">> Testing SSH to bastion..."
if ssh -i "$PRIV_KEY_PATH" -o StrictHostKeyChecking=no "ubuntu@${BASTION_IP}" 'echo ok-from-bastion' 2>/dev/null; then
  echo "   SSH OK."
else
  echo "WARN: SSH test failed. Check security groups, key pair, or user."
fi

echo "Done."
