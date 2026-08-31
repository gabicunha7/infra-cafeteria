#!/bin/bash
# Teste rapido de conexao com as instancias de front, sem depender do ansible.cfg.
set -e
cd "$(dirname "$0")"

export ANSIBLE_HOST_KEY_CHECKING=False

ansible front \
  -i inventories/production.ini \
  --private-key ~/.ssh/meupardechaves.pem \
  -u ubuntu \
  -m ping
