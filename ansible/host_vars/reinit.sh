#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GV_ALL="$ROOT_DIR/group_vars/all.yml"
KNOWN_HOSTS="${HOME}/.ssh/known_hosts"
CONTROL_DIR="${HOME}/.ansible/cp"

usage() {
  cat <<EOF
Usage:
  $0 --bastion <IP> [--run] [--limit <pattern>] [--tags <tags>]

Examples:
  $0 --bastion 203.0.113.10
  $0 --bastion 203.0.113.10 --run
  $0 --bastion 203.0.113.10 --run --limit web --tags filebeat,filebeat_config
EOF
}

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
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ -n "$BASTION_IP" ]] || { echo "ERROR: --bastion <IP> is required"; exit 1; }

echo ">>> Update bastion_host in ${GV_ALL} -> ${BASTION_IP}"
tmpfile="$(mktemp)"
awk -v ip="$BASTION_IP" '
  BEGIN{done=0}
  /^bastion_host:/ { print "bastion_host: \"" ip "\""; done=1; next }
  {print}
  END{if(!done) print "bastion_host: \"" ip "\""}
' "$GV_ALL" > "$tmpfile" && mv "$tmpfile" "$GV_ALL"

echo ">>> Clean SSH control sockets"
rm -f "${CONTROL_DIR}/"* || true

echo ">>> Drop old known_hosts entries for bastion"
[[ -f "$KNOWN_HOSTS" ]] && ssh-keygen -R "$BASTION_IP" || true

echo ">>> Quick raw SSH to bastion"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i "${HOME}/.ssh/id_rsa" "ubuntu@${BASTION_IP}" true

echo ">>> Sanity: no stray '%(' anywhere"
grep -R --line-number '%(' "$ROOT_DIR"/hosts.ini "$ROOT_DIR"/group_vars "$ROOT_DIR"/host_vars "$ROOT_DIR"/ansible.cfg || true

echo ">>> Ansible ping bastion"
ansible -i "$ROOT_DIR/hosts.ini" bastion -m ping -o -vv

echo ">>> Ansible ping internal via ProxyJump"
ansible -i "$ROOT_DIR/hosts.ini" web:elastic_nodes -m ping -o -vv

if [[ $DO_RUN -eq 1 ]]; then
  echo ">>> Run playbook"
  ansible-playbook -i "$ROOT_DIR/hosts.ini" "$ROOT_DIR/site.yml" $LIMIT_ARG $TAGS_ARG
else
  echo "OK. Connectivity verified. Add --run to execute playbook."
fi
