#!/bin/bash
# Roda o playbook do front sem depender do ansible.cfg (que o WSL ignora
# em pastas do Windows por ser "world-writable"). Passa tudo explicito.
set -e
cd "$(dirname "$0")"

export ANSIBLE_HOST_KEY_CHECKING=False

ansible-playbook \
  -i inventories/production.ini \
  --private-key ~/.ssh/meupardechaves.pem \
  -u ubuntu \
  playbooks/front.yml "$@"
