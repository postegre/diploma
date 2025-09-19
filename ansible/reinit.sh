#!/usr/bin/env bash
set -euo pipefail

# все пути — от папки скрипта (ansible/)
ANS_DIR="$(cd "$(dirname "$0")" && pwd)"
GV_ALL="${ANS_DIR}/group_vars/all.yml"
HOSTS="${ANS_DIR}/hosts.ini"
PLAY="${ANS_DIR}/site.yml"

BASTION_IP=""
DO_RUN=0
LIMIT_ARG=""
TAGS_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bastion) BASTION_IP="${2:-}"; shift 2 ;;
    --run) DO_RUN=1; shift ;;
    --limit) LIMIT_ARG="--limit ${2:-}"; shift 2 ;;
    --tags)  TAGS_ARG="--tags ${2:-}"; shift 2 ;;
    -h|--help) echo "Usage: $0 --bastion IP [--run] [--limit PATTERN] [--tags TAGS]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

[[ -n "$BASTION_IP" ]] || { echo "ERROR: --bastion IP is required"; exit 1; }
[[ -f "$GV_ALL" ]]  || { echo "ERROR: $GV_ALL not found"; exit 1; }
[[ -f "$HOSTS" ]]   || { echo "ERROR: $HOSTS not found"; exit 1; }

# обновляем bastion_host в group_vars/all.yml (или добавим, если нет)
tmp="$(mktemp)"
awk -v ip="$BASTION_IP" '
  BEGIN{done=0}
  /^bastion_host:/ {print "bastion_host: \"" ip "\""; done=1; next}
  {print}
  END{if(!done) print "bastion_host: \"" ip "\""}
' "$GV_ALL" > "$tmp" && mv "$tmp" "$GV_ALL"
echo "bastion_host => $BASTION_IP"

# чистим control sockets и known_hosts записи бастиона
rm -f "${HOME}/.ansible/cp/"* 2>/dev/null || true
ssh-keygen -R "$BASTION_IP" >/dev/null 2>&1 || true

# прогреем known_hosts
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${HOME}/.ssh/id_rsa" "ubuntu@${BASTION_IP}" true || true

# быстрый ping (не обязателен)
ansible -i "$HOSTS" bastion -m ping -o || true
ansible -i "$HOSTS" web:elastic_nodes -m ping -o || true

# запуск плейбука по желанию
if [[ $DO_RUN -eq 1 ]]; then
  [[ -f "$PLAY" ]] || { echo "ERROR: $PLAY not found"; exit 1; }
  ansible-playbook -i "$HOSTS" "$PLAY" $LIMIT_ARG $TAGS_ARG
else
  echo "Done. Add --run to execute playbook."
fi
