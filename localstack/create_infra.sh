#!/bin/bash
set -e
cd "$(dirname "$0")"
source ./config.sh

command -v jq >/dev/null || { echo "jq nao encontrado. Instale com: sudo apt install jq"; exit 1; }
command -v aws >/dev/null || { echo "aws cli nao encontrado."; exit 1; }

if [ -f "$STATE_FILE" ]; then
  echo "Ja existe $STATE_FILE - parece que a infra ja foi criada."
  echo "Rode ./destroy_infra.sh primeiro se quiser recriar do zero."
  exit 1
fi
echo "# Gerado por create_infra.sh - $(date)" > "$STATE_FILE"

echo "== VPC =="
VPC_ID=$(awsl ec2 create-vpc --cidr-block "$VPC_CIDR" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$PROJECT-vpc}]" \
  --query 'Vpc.VpcId' --output text)
save_id VPC_ID "$VPC_ID"
awsl ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
awsl ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'
echo "VPC: $VPC_ID"

echo "== Internet Gateway =="
IGW_ID=$(awsl ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$PROJECT-igw}]" \
  --query 'InternetGateway.InternetGatewayId' --output text)
save_id IGW_ID "$IGW_ID"
awsl ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
echo "IGW: $IGW_ID"

echo "== Subnets publicas =="
SUBNET_PUBLIC_FRONT_A=$(awsl ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PUBLIC_FRONT_A_CIDR" --availability-zone "$AZ_A" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT-public-front-a}]" --query 'Subnet.SubnetId' --output text)
save_id SUBNET_PUBLIC_FRONT_A "$SUBNET_PUBLIC_FRONT_A"
awsl ec2 modify-subnet-attribute --subnet-id "$SUBNET_PUBLIC_FRONT_A" --map-public-ip-on-launch

SUBNET_PUBLIC_FRONT_B=$(awsl ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PUBLIC_FRONT_B_CIDR" --availability-zone "$AZ_B" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT-public-front-b}]" --query 'Subnet.SubnetId' --output text)
save_id SUBNET_PUBLIC_FRONT_B "$SUBNET_PUBLIC_FRONT_B"
awsl ec2 modify-subnet-attribute --subnet-id "$SUBNET_PUBLIC_FRONT_B" --map-public-ip-on-launch
echo "front-a: $SUBNET_PUBLIC_FRONT_A / front-b: $SUBNET_PUBLIC_FRONT_B"

echo "== Subnets privadas =="
SUBNET_PRIVATE_BACKEND_A=$(awsl ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PRIVATE_BACKEND_A_CIDR" --availability-zone "$AZ_A" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT-private-backend-a}]" --query 'Subnet.SubnetId' --output text)
save_id SUBNET_PRIVATE_BACKEND_A "$SUBNET_PRIVATE_BACKEND_A"

SUBNET_PRIVATE_BACKEND_B=$(awsl ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PRIVATE_BACKEND_B_CIDR" --availability-zone "$AZ_B" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT-private-backend-b}]" --query 'Subnet.SubnetId' --output text)
save_id SUBNET_PRIVATE_BACKEND_B "$SUBNET_PRIVATE_BACKEND_B"

SUBNET_PRIVATE_DB=$(awsl ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PRIVATE_DB_CIDR" --availability-zone "$AZ_A" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT-private-db}]" --query 'Subnet.SubnetId' --output text)
save_id SUBNET_PRIVATE_DB "$SUBNET_PRIVATE_DB"

SUBNET_PRIVATE_MESSAGING_B=$(awsl ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PRIVATE_MESSAGING_B_CIDR" --availability-zone "$AZ_B" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT-private-messaging-b}]" --query 'Subnet.SubnetId' --output text)
save_id SUBNET_PRIVATE_MESSAGING_B "$SUBNET_PRIVATE_MESSAGING_B"
echo "backend-a: $SUBNET_PRIVATE_BACKEND_A / backend-b: $SUBNET_PRIVATE_BACKEND_B / db: $SUBNET_PRIVATE_DB / messaging-b: $SUBNET_PRIVATE_MESSAGING_B"

echo "== Route table publica =="
RT_PUBLIC=$(awsl ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$PROJECT-rt-public}]" --query 'RouteTable.RouteTableId' --output text)
save_id RT_PUBLIC "$RT_PUBLIC"
awsl ec2 create-route --route-table-id "$RT_PUBLIC" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
awsl ec2 associate-route-table --route-table-id "$RT_PUBLIC" --subnet-id "$SUBNET_PUBLIC_FRONT_A" >/dev/null
awsl ec2 associate-route-table --route-table-id "$RT_PUBLIC" --subnet-id "$SUBNET_PUBLIC_FRONT_B" >/dev/null

echo "== Route table privada =="
RT_PRIVATE=$(awsl ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$PROJECT-rt-private}]" --query 'RouteTable.RouteTableId' --output text)
save_id RT_PRIVATE "$RT_PRIVATE"
awsl ec2 associate-route-table --route-table-id "$RT_PRIVATE" --subnet-id "$SUBNET_PRIVATE_BACKEND_A" >/dev/null
awsl ec2 associate-route-table --route-table-id "$RT_PRIVATE" --subnet-id "$SUBNET_PRIVATE_BACKEND_B" >/dev/null
awsl ec2 associate-route-table --route-table-id "$RT_PRIVATE" --subnet-id "$SUBNET_PRIVATE_DB" >/dev/null
awsl ec2 associate-route-table --route-table-id "$RT_PRIVATE" --subnet-id "$SUBNET_PRIVATE_MESSAGING_B" >/dev/null

echo "== NAT Gateway (best-effort - suporte varia no plano gratuito do LocalStack) =="
set +e
EIP_ALLOC=$(awsl ec2 allocate-address --domain vpc --query 'AllocationId' --output text 2>/tmp/ls_nat_err)
EIP_OK=$?
set -e
if [ "$EIP_OK" -eq 0 ] && [ -n "$EIP_ALLOC" ] && [ "$EIP_ALLOC" != "None" ]; then
  save_id EIP_ALLOC "$EIP_ALLOC"
  set +e
  NGW_ID=$(awsl ec2 create-nat-gateway --subnet-id "$SUBNET_PUBLIC_FRONT_A" --allocation-id "$EIP_ALLOC" \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$PROJECT-ngw}]" \
    --query 'NatGateway.NatGatewayId' --output text 2>/tmp/ls_nat_err2)
  NGW_OK=$?
  set -e
  if [ "$NGW_OK" -eq 0 ] && [ -n "$NGW_ID" ] && [ "$NGW_ID" != "None" ]; then
    save_id NGW_ID "$NGW_ID"
    awsl ec2 create-route --route-table-id "$RT_PRIVATE" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NGW_ID" >/dev/null 2>&1 \
      || echo "aviso: nao consegui criar a rota pro NAT, seguindo sem"
    echo "NAT Gateway: $NGW_ID"
  else
    echo "aviso: NAT Gateway nao suportado nesta instancia do LocalStack - seguindo sem ele (nao afeta o resto)"
  fi
else
  echo "aviso: Elastic IP nao suportado nesta instancia do LocalStack - seguindo sem NAT Gateway"
fi

echo "== Security Groups =="
SG_ALB_PUBLIC=$(awsl ec2 create-security-group --group-name "$PROJECT-alb-public" --description "ALB publico" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
save_id SG_ALB_PUBLIC "$SG_ALB_PUBLIC"
awsl ec2 authorize-security-group-ingress --group-id "$SG_ALB_PUBLIC" --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null

SG_FRONT=$(awsl ec2 create-security-group --group-name "$PROJECT-front" --description "Instancias de frontend" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
save_id SG_FRONT "$SG_FRONT"
awsl ec2 authorize-security-group-ingress --group-id "$SG_FRONT" --protocol tcp --port 80 --source-group "$SG_ALB_PUBLIC" >/dev/null
awsl ec2 authorize-security-group-ingress --group-id "$SG_FRONT" --protocol tcp --port 22 --cidr "$SSH_CIDR" >/dev/null

SG_ALB_INTERNAL=$(awsl ec2 create-security-group --group-name "$PROJECT-alb-internal" --description "ALB interno" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
save_id SG_ALB_INTERNAL "$SG_ALB_INTERNAL"
awsl ec2 authorize-security-group-ingress --group-id "$SG_ALB_INTERNAL" --protocol tcp --port "$BACKEND_PORT" --source-group "$SG_FRONT" >/dev/null

SG_BACKEND=$(awsl ec2 create-security-group --group-name "$PROJECT-backend" --description "Instancias de backend" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
save_id SG_BACKEND "$SG_BACKEND"
awsl ec2 authorize-security-group-ingress --group-id "$SG_BACKEND" --protocol tcp --port "$BACKEND_PORT" --source-group "$SG_ALB_INTERNAL" >/dev/null
awsl ec2 authorize-security-group-ingress --group-id "$SG_BACKEND" --protocol tcp --port 22 --cidr "$VPC_CIDR" >/dev/null

SG_DB=$(awsl ec2 create-security-group --group-name "$PROJECT-db" --description "Instancia de banco de dados" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
save_id SG_DB "$SG_DB"
awsl ec2 authorize-security-group-ingress --group-id "$SG_DB" --protocol tcp --port "$DB_PORT" --source-group "$SG_BACKEND" >/dev/null
awsl ec2 authorize-security-group-ingress --group-id "$SG_DB" --protocol tcp --port 22 --cidr "$VPC_CIDR" >/dev/null

SG_MESSAGING=$(awsl ec2 create-security-group --group-name "$PROJECT-messaging" --description "Instancia de mensageria (RabbitMQ)" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
save_id SG_MESSAGING "$SG_MESSAGING"
awsl ec2 authorize-security-group-ingress --group-id "$SG_MESSAGING" --protocol tcp --port "$RABBITMQ_AMQP_PORT" --source-group "$SG_BACKEND" >/dev/null
awsl ec2 authorize-security-group-ingress --group-id "$SG_MESSAGING" --protocol tcp --port "$RABBITMQ_MGMT_PORT" --cidr "$VPC_CIDR" >/dev/null
awsl ec2 authorize-security-group-ingress --group-id "$SG_MESSAGING" --protocol tcp --port 22 --cidr "$VPC_CIDR" >/dev/null
echo "7 security groups criados"

echo "== Par de chaves =="
KEY_NAME="$PROJECT-key"
awsl ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
chmod 600 "${KEY_NAME}.pem" 2>/dev/null || true
save_id KEY_NAME "$KEY_NAME"
echo "chave: ${KEY_NAME}.pem (o LocalStack nao roda maquina real, fica so por completude)"

echo "== Instancias EC2 =="
run_instance() {
  awsl ec2 run-instances \
    --image-id "$AMI_ID" --instance-type "$4" --subnet-id "$2" --security-group-ids "$3" --key-name "$KEY_NAME" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$1}]" \
    --query 'Instances[0].InstanceId' --output text
}
INSTANCE_FRONT_A=$(run_instance "$PROJECT-front-a" "$SUBNET_PUBLIC_FRONT_A" "$SG_FRONT" "$FRONT_INSTANCE_TYPE"); save_id INSTANCE_FRONT_A "$INSTANCE_FRONT_A"
INSTANCE_FRONT_B=$(run_instance "$PROJECT-front-b" "$SUBNET_PUBLIC_FRONT_B" "$SG_FRONT" "$FRONT_INSTANCE_TYPE"); save_id INSTANCE_FRONT_B "$INSTANCE_FRONT_B"
INSTANCE_BACKEND_A=$(run_instance "$PROJECT-backend-a" "$SUBNET_PRIVATE_BACKEND_A" "$SG_BACKEND" "$BACKEND_INSTANCE_TYPE"); save_id INSTANCE_BACKEND_A "$INSTANCE_BACKEND_A"
INSTANCE_BACKEND_B=$(run_instance "$PROJECT-backend-b" "$SUBNET_PRIVATE_BACKEND_B" "$SG_BACKEND" "$BACKEND_INSTANCE_TYPE"); save_id INSTANCE_BACKEND_B "$INSTANCE_BACKEND_B"
INSTANCE_DB=$(run_instance "$PROJECT-db" "$SUBNET_PRIVATE_DB" "$SG_DB" "$DB_INSTANCE_TYPE"); save_id INSTANCE_DB "$INSTANCE_DB"
INSTANCE_MESSAGING_B=$(run_instance "$PROJECT-messaging-b" "$SUBNET_PRIVATE_MESSAGING_B" "$SG_MESSAGING" "$MESSAGING_INSTANCE_TYPE"); save_id INSTANCE_MESSAGING_B "$INSTANCE_MESSAGING_B"
echo "6 instancias criadas (registros no LocalStack, sem maquina real por tras)"

echo "== ALB publico (front) =="
ALB_PUBLIC_ARN=$(awsl elbv2 create-load-balancer --name "$PROJECT-alb-public" --type application --scheme internet-facing \
  --security-groups "$SG_ALB_PUBLIC" --subnets "$SUBNET_PUBLIC_FRONT_A" "$SUBNET_PUBLIC_FRONT_B" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
save_id ALB_PUBLIC_ARN "$ALB_PUBLIC_ARN"

TG_FRONT_ARN=$(awsl elbv2 create-target-group --name "$PROJECT-tg-front" --protocol HTTP --port 80 --vpc-id "$VPC_ID" \
  --target-type instance --health-check-path / --query 'TargetGroups[0].TargetGroupArn' --output text)
save_id TG_FRONT_ARN "$TG_FRONT_ARN"
awsl elbv2 register-targets --target-group-arn "$TG_FRONT_ARN" --targets Id="$INSTANCE_FRONT_A",Port=80 Id="$INSTANCE_FRONT_B",Port=80 >/dev/null
awsl elbv2 create-listener --load-balancer-arn "$ALB_PUBLIC_ARN" --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TG_FRONT_ARN" >/dev/null

echo "== ALB interno (backend) =="
ALB_INTERNAL_ARN=$(awsl elbv2 create-load-balancer --name "$PROJECT-alb-backend" --type application --scheme internal \
  --security-groups "$SG_ALB_INTERNAL" --subnets "$SUBNET_PRIVATE_BACKEND_A" "$SUBNET_PRIVATE_BACKEND_B" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
save_id ALB_INTERNAL_ARN "$ALB_INTERNAL_ARN"

TG_BACKEND_ARN=$(awsl elbv2 create-target-group --name "$PROJECT-tg-backend" --protocol HTTP --port "$BACKEND_PORT" --vpc-id "$VPC_ID" \
  --target-type instance --health-check-path / --query 'TargetGroups[0].TargetGroupArn' --output text)
save_id TG_BACKEND_ARN "$TG_BACKEND_ARN"
awsl elbv2 register-targets --target-group-arn "$TG_BACKEND_ARN" --targets Id="$INSTANCE_BACKEND_A",Port="$BACKEND_PORT" Id="$INSTANCE_BACKEND_B",Port="$BACKEND_PORT" >/dev/null
awsl elbv2 create-listener --load-balancer-arn "$ALB_INTERNAL_ARN" --protocol HTTP --port "$BACKEND_PORT" \
  --default-actions Type=forward,TargetGroupArn="$TG_BACKEND_ARN" >/dev/null
echo "2 ALBs criados"

echo "== Buckets S3 =="
SUFFIX=$(head -c 16 /dev/urandom | md5sum | cut -c1-8)
save_id BUCKET_SUFFIX "$SUFFIX"
for name in "${S3_BUCKETS[@]}"; do
  bucket="$PROJECT-$name-$SUFFIX"
  awsl s3api create-bucket --bucket "$bucket" >/dev/null
  awsl s3api put-bucket-versioning --bucket "$bucket" --versioning-configuration Status=Enabled >/dev/null
  awsl s3api put-bucket-encryption --bucket "$bucket" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' >/dev/null
  awsl s3api put-public-access-block --bucket "$bucket" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true >/dev/null
  UPPER=$(echo "$name" | tr '[:lower:]' '[:upper:]')
  save_id "BUCKET_${UPPER}" "$bucket"
  echo "bucket criado: $bucket"
done

echo ""
echo "=== Infra criada com sucesso! IDs salvos em .ids.env ==="
FRONT_DNS=$(awsl elbv2 describe-load-balancers --load-balancer-arns "$ALB_PUBLIC_ARN" --query 'LoadBalancers[0].DNSName' --output text)
BACKEND_DNS=$(awsl elbv2 describe-load-balancers --load-balancer-arns "$ALB_INTERNAL_ARN" --query 'LoadBalancers[0].DNSName' --output text)
echo "ALB publico (front):   $FRONT_DNS"
echo "ALB interno (backend): $BACKEND_DNS"
