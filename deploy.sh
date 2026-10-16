#!/usr/bin/env bash
set -euo pipefail

export ANSIBLE_CONFIG="$(pwd)/ansible.cfg"

if [ -f .env ]; then
  set -a
  source <(tr -d '\r' < .env)
  set +a
fi

if [ -f ./id_rsa ]; then
  install -m 600 ./id_rsa /tmp/id_rsa_tp3
  export ANSIBLE_PRIVATE_KEY_FILE=/tmp/id_rsa_tp3
fi

ansible-playbook ansible/playbook.yml "$@"