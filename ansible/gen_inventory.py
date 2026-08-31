#!/usr/bin/env python3
"""
Gera infra-cafeteria/ansible/inventories/production.ini a partir dos outputs do Terraform.

Uso:
  cd infra-cafeteria/terraform
  terraform output -json | python3 ../ansible/gen_inventory.py > ../ansible/inventories/production.ini
"""

import json
import sys


def carregar_json_stdin():
    raw = sys.stdin.buffer.read()

    if raw.startswith(b"\xff\xfe"):
        texto = raw.decode("utf-16-le")
    elif raw.startswith(b"\xfe\xff"):
        texto = raw.decode("utf-16-be")
    elif raw.startswith(b"\xef\xbb\xbf"):
        texto = raw.decode("utf-8-sig")
    else:
        texto = raw.decode("utf-8")

    texto = texto.lstrip("\ufeff")

    return json.loads(texto)


data = carregar_json_stdin()


def val(key):
    return data[key]["value"]


out = f"""[front]
front-a ansible_host={val("front_a_public_ip")}
front-b ansible_host={val("front_b_public_ip")}

[backend]
backend-a ansible_host={val("backend_a_private_ip")}
backend-b ansible_host={val("backend_b_private_ip")}

[db]
db ansible_host={val("db_private_ip")}

[private:children]
backend
db

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/meupardechaves.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ConnectTimeout=10'
backend_alb_dns={val("alb_backend_dns")}
efs_dns={val("efs_dns_name")}

[private:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ProxyJump=ubuntu@{val("front_a_public_ip")}'
"""

print(out.strip())
