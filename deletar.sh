#!/bin/bash
set -euo pipefail

REGION="us-east-1"

TAG_VPC_NAME="vpc-cafeteria"
TAG_EFS_NAME="efs-cafeteria"
TAG_ALB_NAME="alb-cafeteria"
TAG_NAT_NAME="nat-gateway-cafeteria"
SEC_GROUP_NAME="meugrupodeseguranca"
KEY_NAME="meupardechaves"
BUCKET_RAW="raw-9d2c58159d753"
BUCKET_TRUSTED="trusted-9d2c58159d753"
BUCKET_CLIENT="client-9d2c58159d753"

echo "Região: $REGION"
echo "Iniciando remoção da infraestrutura..."

wait_for() {
  local desc="$1"; shift
  local cmd="$*"
  local timeout=600
  local interval=5
  local elapsed=0
  echo "Aguardando: $desc"
  while true; do
    if eval "$cmd"; then
      echo "Condição satisfeita: $desc"
      return 0
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
    if [ $elapsed -ge $timeout ]; then
      echo "Timeout aguardando: $desc" >&2
      return 1
    fi
  done
}

VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Name,Values=${TAG_VPC_NAME}" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "VPC com tag Name=${TAG_VPC_NAME} não encontrada. Saindo."
  exit 0
fi
echo "VPC encontrada: $VPC_ID"

ALB_ARN=$(aws elbv2 describe-load-balancers --region $REGION --names "${TAG_ALB_NAME}" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
if [ -n "$ALB_ARN" ]; then
  echo "ALB encontrado: $ALB_ARN"
  LISTENER_ARNS=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --region $REGION --query 'Listeners[*].ListenerArn' --output text || echo "")
  for l in $LISTENER_ARNS; do
    echo "Deletando listener $l"
    aws elbv2 delete-listener --listener-arn $l --region $REGION || true
  done

  echo "Deletando ALB $ALB_ARN"
  aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $REGION

  echo "Aguardando ALB ser deletado..."
  aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARN --region $REGION || true
else
  echo "ALB não encontrado, pulando."
fi

TG_ARNS=$(aws elbv2 describe-target-groups --region $REGION --names "tg-cafeteria" --query 'TargetGroups[*].TargetGroupArn' --output text 2>/dev/null || echo "")
for tg in $TG_ARNS; do
  echo "Deletando target group $tg"
  aws elbv2 delete-target-group --target-group-arn $tg --region $REGION || true
done

echo "Localizando instâncias com tags do projeto..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:Name,Values=ec2-publica-front-*,ec2-privada-back,ec2-publica-front-f1,ec2-publica-front-f2,ec2-publica-front-lb" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)
if [ -n "$INSTANCE_IDS" ]; then
  echo "Instâncias encontradas: $INSTANCE_IDS"
  echo "Terminando instâncias..."
  aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_IDS --output text || true

  echo "Aguardando instâncias terminarem..."
  for id in $INSTANCE_IDS; do
    aws ec2 wait instance-terminated --region $REGION --instance-ids $id || true
    echo "Instância terminada: $id"
  done
else
  echo "Nenhuma instância encontrada para terminar."
fi

NAT_ID=$(aws ec2 describe-nat-gateways \
  --region $REGION \
  --filters "Name=tag:Name,Values=${TAG_NAT_NAME}" "Name=state,Values=available" \
  --query 'NatGateways[0].NatGatewayId' \
  --output text 2>/dev/null || echo "")

if [ -n "$NAT_ID" ] && [ "$NAT_ID" != "None" ]; then
  echo "Deletando NAT Gateway $NAT_ID"
  aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id $NAT_ID || true
  echo "Aguardando NAT Gateway ser deletado..."
  aws ec2 wait nat-gateway-deleted --region $REGION --nat-gateway-ids $NAT_ID
else
  echo "Nenhum NAT Gateway em estado 'available' encontrado com a tag ${TAG_NAT_NAME}, pulando."
fi

echo "Procurando Elastic IPs associados a instâncias terminadas ou soltos..."
ALLOC_IDS=$(aws ec2 describe-addresses --region $REGION --query 'Addresses[?AllocationId!=null].AllocationId' --output text || echo "")
for alloc in $ALLOC_IDS; do
  ASSOC_ID=$(aws ec2 describe-addresses --region $REGION --allocation-ids $alloc --query 'Addresses[0].AssociationId' --output text || echo "")
  if [ -n "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
    echo "Desassociando EIP allocation $alloc (association $ASSOC_ID)"
    aws ec2 disassociate-address --region $REGION --association-id $ASSOC_ID || true
  fi
  echo "Liberando EIP allocation $alloc"
  aws ec2 release-address --region $REGION --allocation-id $alloc || true
done

EFS_ID=$(aws efs describe-file-systems \
  --region $REGION \
  --query "FileSystems[?Tags[?Key=='Name' && Value=='${TAG_EFS_NAME}']].FileSystemId | [0]" \
  --output text 2>/dev/null || echo "")

if [ -n "$EFS_ID" ] && [ "$EFS_ID" != "None" ]; then
  echo "EFS encontrado: $EFS_ID"
  MOUNT_TARGET_IDS=$(aws efs describe-mount-targets --file-system-id $EFS_ID --region $REGION --query 'MountTargets[*].MountTargetId' --output text || echo "")
  for mt in $MOUNT_TARGET_IDS; do
    echo "Deletando mount target $mt"
    aws efs delete-mount-target --mount-target-id $mt --region $REGION || true
  done

  echo "Aguardando todos os mount targets do EFS serem removidos..."
  wait_for "mount targets removidos para $EFS_ID" "test -z \"\$(aws efs describe-mount-targets --file-system-id $EFS_ID --region $REGION --query 'MountTargets[*].MountTargetId' --output text 2>/dev/null || echo '')\""

  echo "Deletando file system EFS $EFS_ID"
  aws efs delete-file-system --file-system-id $EFS_ID --region $REGION || true

  echo "Aguardando EFS ser deletado..."
  while aws efs describe-file-systems --file-system-id $EFS_ID --region $REGION --query 'FileSystems[0].FileSystemId' --output text 2>/dev/null; do
    echo "Ainda existe, aguardando..."
    sleep 10
  done
  echo "EFS $EFS_ID deletado com sucesso."
else
  echo "EFS não encontrado, pulando."
fi

SG_ID=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=${SEC_GROUP_NAME}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
  echo "Deletando security group $SG_ID"
  aws ec2 delete-security-group --region $REGION --group-id $SG_ID || true
else
  echo "Security group ${SEC_GROUP_NAME} não encontrado."
fi

for RT_NAME in "rt-publica" "rt-privada"; do
  RT_ID=$(aws ec2 describe-route-tables --region $REGION --filters "Name=tag:Name,Values=${RT_NAME}" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || echo "")
  if [ -n "$RT_ID" ] && [ "$RT_ID" != "None" ]; then
    echo "Processando route table $RT_NAME ($RT_ID)"
    ASSOC_IDS=$(aws ec2 describe-route-tables --region $REGION --route-table-ids $RT_ID --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' --output text || echo "")
    for a in $ASSOC_IDS; do
      echo "Removendo associação $a"
      aws ec2 disassociate-route-table --region $REGION --association-id $a || true
    done
    echo "Deletando route table $RT_ID"
    aws ec2 delete-route-table --region $REGION --route-table-id $RT_ID || true
  else
    echo "Route table $RT_NAME não encontrada."
  fi
done

for SUB_CIDR in "subnet-publica-a" "subnet-publica-b" "subnet-privada"; do
  SUB_ID=$(aws ec2 describe-subnets --region $REGION --filters "Name=tag:Name,Values=${SUB_CIDR}" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "")
  if [ -n "$SUB_ID" ] && [ "$SUB_ID" != "None" ]; then
    echo "Deletando subnet $SUB_ID (tag $SUB_CIDR)"
    aws ec2 delete-subnet --region $REGION --subnet-id $SUB_ID || true
  else
    echo "Subnet com tag $SUB_CIDR não encontrada."
  fi
done

IGW_ID=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=tag:Name,Values=igw-cafeteria" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "")
if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
  echo "Desanexando IGW $IGW_ID da VPC $VPC_ID"
  aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW_ID --vpc-id $VPC_ID || true
  echo "Deletando IGW $IGW_ID"
  aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $IGW_ID || true
else
  echo "IGW não encontrado."
fi

echo "Tentando deletar VPC $VPC_ID"
aws ec2 delete-vpc --region $REGION --vpc-id $VPC_ID || true
echo "VPC $VPC_ID solicitada para exclusão (pode falhar se ainda houver dependências)."

echo "Deletando key pair $KEY_NAME"
aws ec2 delete-key-pair --region $REGION --key-name $KEY_NAME || true
if [ -f "${KEY_NAME}.pem" ]; then
  rm -f "${KEY_NAME}.pem" || true
fi

for BUCKET in "$BUCKET_RAW" "$BUCKET_TRUSTED" "$BUCKET_CLIENT"; do
  if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
    echo "Esvaziando bucket $BUCKET"
    aws s3 rm "s3://$BUCKET" --recursive || true
    aws s3api delete-bucket --bucket "$BUCKET" --region $REGION || true
    echo "Bucket $BUCKET deletado (ou solicitação enviada)."
  else
    echo "Bucket $BUCKET não existe, pulando."
  fi
done

echo "Limpeza solicitada. Alguns recursos podem demorar para serem totalmente removidos pela AWS."
echo "Verifique o console AWS ou use 'aws resourcegroupstaggingapi get-resources' para confirmar."

exit 0
