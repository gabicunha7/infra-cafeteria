#!/bin/bash
cd "$(dirname "$0")"
source ./config.sh

if [ ! -f "$STATE_FILE" ]; then
  echo "Nao encontrei .ids.env - nada para destruir (ou a infra ja foi destruida)."
  exit 0
fi
source "$STATE_FILE"

echo "== Buckets S3 =="
for name in "${S3_BUCKETS[@]}"; do
  UPPER=$(echo "$name" | tr '[:lower:]' '[:upper:]')
  var="BUCKET_${UPPER}"
  bucket="${!var}"
  if [ -n "$bucket" ]; then
    awsl s3 rb "s3://$bucket" --force >/dev/null 2>&1 && echo "removido: $bucket" || echo "aviso: falha ao remover $bucket (ou ja nao existe)"
  fi
done

echo "== ALBs e Target Groups =="
[ -n "$ALB_PUBLIC_ARN" ] && awsl elbv2 delete-load-balancer --load-balancer-arn "$ALB_PUBLIC_ARN" >/dev/null 2>&1
[ -n "$ALB_INTERNAL_ARN" ] && awsl elbv2 delete-load-balancer --load-balancer-arn "$ALB_INTERNAL_ARN" >/dev/null 2>&1
sleep 2
[ -n "$TG_FRONT_ARN" ] && awsl elbv2 delete-target-group --target-group-arn "$TG_FRONT_ARN" >/dev/null 2>&1
[ -n "$TG_BACKEND_ARN" ] && awsl elbv2 delete-target-group --target-group-arn "$TG_BACKEND_ARN" >/dev/null 2>&1
echo "ALBs removidos"

echo "== Instancias EC2 =="
for v in INSTANCE_FRONT_A INSTANCE_FRONT_B INSTANCE_BACKEND_A INSTANCE_BACKEND_B INSTANCE_DB INSTANCE_MESSAGING_B; do
  id="${!v}"
  [ -n "$id" ] && awsl ec2 terminate-instances --instance-ids "$id" >/dev/null 2>&1
done
echo "instancias terminadas"

echo "== Par de chaves =="
if [ -n "$KEY_NAME" ]; then
  awsl ec2 delete-key-pair --key-name "$KEY_NAME" >/dev/null 2>&1
  rm -f "${KEY_NAME}.pem"
fi

echo "== Security Groups =="
for v in SG_MESSAGING SG_DB SG_BACKEND SG_ALB_INTERNAL SG_FRONT SG_ALB_PUBLIC; do
  id="${!v}"
  [ -n "$id" ] && awsl ec2 delete-security-group --group-id "$id" >/dev/null 2>&1
done

echo "== NAT Gateway / EIP =="
if [ -n "$NGW_ID" ]; then
  awsl ec2 delete-nat-gateway --nat-gateway-id "$NGW_ID" >/dev/null 2>&1
  sleep 2
fi
[ -n "$EIP_ALLOC" ] && awsl ec2 release-address --allocation-id "$EIP_ALLOC" >/dev/null 2>&1

echo "== Route tables =="
for v in RT_PRIVATE RT_PUBLIC; do
  id="${!v}"
  [ -n "$id" ] && awsl ec2 delete-route-table --route-table-id "$id" >/dev/null 2>&1
done

echo "== Subnets =="
for v in SUBNET_PRIVATE_MESSAGING_B SUBNET_PRIVATE_DB SUBNET_PRIVATE_BACKEND_B SUBNET_PRIVATE_BACKEND_A SUBNET_PUBLIC_FRONT_B SUBNET_PUBLIC_FRONT_A; do
  id="${!v}"
  [ -n "$id" ] && awsl ec2 delete-subnet --subnet-id "$id" >/dev/null 2>&1
done

echo "== Internet Gateway =="
if [ -n "$IGW_ID" ] && [ -n "$VPC_ID" ]; then
  awsl ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" >/dev/null 2>&1
  awsl ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" >/dev/null 2>&1
fi

echo "== VPC =="
[ -n "$VPC_ID" ] && awsl ec2 delete-vpc --vpc-id "$VPC_ID" >/dev/null 2>&1

rm -f "$STATE_FILE"
echo ""
echo "=== Tudo destruido ==="
