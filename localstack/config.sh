#!/bin/bash
# Configuracao compartilhada - usado por create_infra.sh e destroy_infra.sh.
# NAO precisa editar credenciais: o LocalStack aceita "test"/"test" sempre.

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

ENDPOINT="http://localhost:4566"
PROJECT="cafeteria-ls"

VPC_CIDR="10.0.0.0/20"
AZ_A="us-east-1a"
AZ_B="us-east-1b"

PUBLIC_FRONT_A_CIDR="10.0.1.0/24"
PUBLIC_FRONT_B_CIDR="10.0.2.0/24"
PRIVATE_BACKEND_A_CIDR="10.0.4.0/24"
PRIVATE_BACKEND_B_CIDR="10.0.5.0/24"
PRIVATE_DB_CIDR="10.0.6.0/24"
PRIVATE_MESSAGING_B_CIDR="10.0.7.0/24"

AMI_ID="ami-0360c520857e3138f"
FRONT_INSTANCE_TYPE="t3.small"
BACKEND_INSTANCE_TYPE="t3.small"
DB_INSTANCE_TYPE="t3.medium"
MESSAGING_INSTANCE_TYPE="t3.small"

BACKEND_PORT=8080
DB_PORT=3306
RABBITMQ_AMQP_PORT=5672
RABBITMQ_MGMT_PORT=15672
SSH_CIDR="0.0.0.0/0"

S3_BUCKETS=(raw trusted client)

STATE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.ids.env"

awsl() {
  aws --endpoint-url="$ENDPOINT" --region "$AWS_DEFAULT_REGION" "$@"
}

save_id() {
  echo "export $1=\"$2\"" >> "$STATE_FILE"
}
