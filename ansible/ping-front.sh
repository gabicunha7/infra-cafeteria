#!/bin/bash
set -e
cd "$(dirname "$0")"

export ANSIBLE_HOST_KEY_CHECKING=False

ansible front \
  -i inventories/production.ini \
  --private-key ~/.ssh/meupardechaves.pem \
  -u ubuntu \
  -m ping
