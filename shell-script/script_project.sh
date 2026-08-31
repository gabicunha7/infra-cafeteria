
#!/bin/bash

NOME_CHAVE=meupardechaves
NOME_GRUPO=meugrupodeseguranca
NOME_EC2_PUBLICA_LB=ec2-publica-front-lb
NOME_EC2_PUBLICA_F1=ec2-publica-front-f1
NOME_EC2_PUBLICA_F2=ec2-publica-front-f2
NOME_EC2_PRIVADA=ec2-privada-back
NOME_BUCKET=9d2c58159d753

echo "criando a vpc"
ID_VPC=$(aws ec2 create-vpc --cidr-block 10.0.0.0/24 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=vpc-cafeteria}]' --query 'Vpc.VpcId' --output text)

echo "habilitando DNS na VPC"
aws ec2 modify-vpc-attribute --vpc-id $ID_VPC --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id $ID_VPC --enable-dns-hostnames
echo "DNS habilitado na VPC $ID_VPC"

echo "criando internet gateway"
ID_IGW=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-cafeteria}]' --query 'InternetGateway.InternetGatewayId' --output text)
echo "internet gateway criado"

echo "associando IGW a VPC"
aws ec2 attach-internet-gateway --vpc-id $ID_VPC --internet-gateway-id $ID_IGW
echo "associados"

echo "criando subnet pública"
ID_PUBLIC_SUBNET=$(aws ec2 create-subnet --vpc-id $ID_VPC --cidr-block 10.0.0.0/26 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=subnet-publica-a}]' --query 'Subnet.SubnetId' --output text)
echo "subnet pública criada $ID_PUBLIC_SUBNET"

echo "criando subnet privada"
ID_PRIVATE_SUBNET=$(aws ec2 create-subnet --vpc-id $ID_VPC --cidr-block 10.0.0.64/26 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=subnet-privada}]' --query 'Subnet.SubnetId' --output text)
echo "subnet privada criada $ID_PRIVATE_SUBNET"

echo "criando subnet pública 2"
ID_PUBLIC_SUBNET_2=$(aws ec2 create-subnet --vpc-id $ID_VPC --cidr-block 10.0.0.128/26 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=subnet-publica-b}]' --query 'Subnet.SubnetId' --output text)
echo "subnet pública criada $ID_PUBLIC_SUBNET_2"

echo "criando rt pÚblica"
ID_RT_PUBLICA=$(aws ec2 create-route-table --vpc-id $ID_VPC --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rt-publica}]' --query 'RouteTable.RouteTableId' --output text)
echo "rt pública criada $ID_RT_PUBLICA"

echo "criando rota para igw"
aws ec2 create-route --route-table-id $ID_RT_PUBLICA --destination-cidr-block 0.0.0.0/0 --gateway-id $ID_IGW
echo "criada"

echo "associando subnet 1 a rota"
aws ec2 associate-route-table --subnet-id $ID_PUBLIC_SUBNET --route-table-id $ID_RT_PUBLICA
echo "associadas"

echo "associando subent 2 a rota"
aws ec2 associate-route-table --subnet-id $ID_PUBLIC_SUBNET_2 --route-table-id $ID_RT_PUBLICA
echo "associadas"

echo "criando par de chaves"
aws ec2 create-key-pair --key-name ${NOME_CHAVE} --region us-east-1 --query 'KeyMaterial' --output text > ${NOME_CHAVE}.pem
echo "par de chaves criado"

echo "criando grupo de segurança"
ID_GRUPO=$(aws ec2 create-security-group --group-name ${NOME_GRUPO} --vpc-id ${ID_VPC} --description "grupo de seguranca para o projeto" --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=grupo-seguranca-cafeteria}]' --query 'GroupId' --output text)
echo "grupo de segurança criado $ID_GRUPO"

echo "permitindo acesso pela porta 22"
aws ec2 authorize-security-group-ingress --group-id ${ID_GRUPO} --protocol tcp --port 22 --cidr 0.0.0.0/0
echo "acesso permitido"

echo "permitindo acesso pela porta 80"
aws ec2 authorize-security-group-ingress --group-id ${ID_GRUPO} --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "acesso permitido"

echo "permitindo acesso pela porta 2049"
aws ec2 authorize-security-group-ingress --group-id ${ID_GRUPO} --protocol tcp --port 2049 --cidr 0.0.0.0/0
echo "acesso permitido"


echo "criando EFS"
ID_EFS=$(aws efs create-file-system --performance-mode generalPurpose --throughput-mode bursting --tags Key=Name,Value=efs-cafeteria --query 'FileSystemId' --output text)
echo "EFS criado $ID_EFS"

while true; do
    ESTADO_EFS=$(aws efs describe-file-systems --file-system-id $ID_EFS --query 'FileSystems[0].LifeCycleState' --output text)
    if [ "$ESTADO_EFS" == "available" ]; then
        echo "EFS disponível"
        break
    fi
    sleep 10
done

echo "criando mount target para subnet publica 1"
aws efs create-mount-target --file-system-id $ID_EFS --subnet-id $ID_PUBLIC_SUBNET --security-groups $ID_GRUPO

echo "criando mount target para subnet publica 2"
aws efs create-mount-target --file-system-id $ID_EFS --subnet-id $ID_PUBLIC_SUBNET_2 --security-groups $ID_GRUPO

echo "Aguardando mount targets do EFS ficarem disponíveis..."
while true; do
  STATES=$(aws efs describe-mount-targets --file-system-id $ID_EFS --query 'MountTargets[*].LifeCycleState' --output text)
  DISPONIVEIS=$(echo "$STATES" | grep -o "available" | wc -l)
  TOTAL=$(echo "$STATES" | wc -w)

  if [ "$TOTAL" -gt 0 ] && [ "$DISPONIVEIS" -eq "$TOTAL" ]; then
    echo "Todos os $TOTAL mount targets disponíveis"
    break
  fi

  echo "Ainda aguardando... $DISPONIVEIS/$TOTAL disponíveis"
  sleep 10
done

echo "gerando front1.sh com ID do EFS"
CONTEUDO_HTML=$(printf '<!DOCTYPE html>\n<html>\n<head><meta charset="UTF-8"><title>Cafeteria</title></head>\n<body><h1>Aplicacao Web Cafeteria</h1></body>\n</html>' | base64 -w 0)

cat > front1.sh <<EOF
#!/bin/bash
exec > /var/log/userdata.log 2>&1
set -x
apt update -y
apt install -y nfs-common nginx
systemctl stop nginx

sleep 120

mkdir -p /var/www/html

for i in \$(seq 1 15); do
  if mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${ID_EFS}.efs.us-east-1.amazonaws.com:/ /var/www/html; then
    printf '%s\n' "${ID_EFS}.efs.us-east-1.amazonaws.com:/ /var/www/html nfs4 defaults,_netdev 0 0" | tee -a /etc/fstab > /dev/null
    break
  fi
  sleep 20
done

if ! mountpoint -q /var/www/html; then
  exit 1
fi

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
printf '%s' "${CONTEUDO_HTML}" | base64 -d > /var/www/html/index.html

chown www-data:www-data /var/www/html/index.html
chmod 644 /var/www/html/index.html
systemctl start nginx
systemctl enable nginx
EOF

echo "gerando front2.sh com ID do EFS"
cat > front2.sh <<EOF
#!/bin/bash
exec > /var/log/userdata.log 2>&1
set -x
apt update -y
apt install -y nfs-common nginx
systemctl stop nginx

sleep 120

mkdir -p /var/www/html

for i in \$(seq 1 15); do
  if mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${ID_EFS}.efs.us-east-1.amazonaws.com:/ /var/www/html; then
    printf '%s\n' "${ID_EFS}.efs.us-east-1.amazonaws.com:/ /var/www/html nfs4 defaults,_netdev 0 0" | tee -a /etc/fstab > /dev/null
    break
  fi
  sleep 20
done

if ! mountpoint -q /var/www/html; then
  exit 1
fi

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
systemctl start nginx
systemctl enable nginx
EOF

echo "tentando rodar instancia pública front 1"
ID_INSTANCIA_PUBLICA_F1=$(aws ec2 run-instances --image-id ami-0360c520857e3138f --region us-east-1 --count 1 --security-group-ids ${ID_GRUPO} --user-data file://front1.sh --instance-type t3.small --associate-public-ip-address --subnet-id ${ID_PUBLIC_SUBNET} --key-name ${NOME_CHAVE} --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":10, "VolumeType":"gp3","DeleteOnTermination":true}}]' --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NOME_EC2_PUBLICA_F1}}]" --query 'Instances[0].InstanceId' --output text)
echo "instancia pública criada com sucesso $ID_INSTANCIA_PUBLICA_F1"

echo "criando ip elastico para a instancia pública front 1"
ID_IP_F1=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --region us-east-1 --output text)
echo "ip criado front 1"

while true; do
	ESTADO_INSTANCIA=$(aws ec2 describe-instances --instance-ids ${ID_INSTANCIA_PUBLICA_F1} --query 'Reservations[*].Instances[*].State.Name' --output text --region us-east-1)
	if [ "$ESTADO_INSTANCIA" == "running" ]; then
		echo "Instancia Publica Rodando f1"
		echo "associando os dois"
		aws ec2 associate-address --instance-id ${ID_INSTANCIA_PUBLICA_F1} --allocation-id ${ID_IP_F1} --region us-east-1
		break
	fi
	sleep 5
done

echo "tentando rodar instancia pública front 2"
ID_INSTANCIA_PUBLICA_F2=$(aws ec2 run-instances --image-id ami-0360c520857e3138f --region us-east-1 --count 1 --security-group-ids ${ID_GRUPO} --user-data file://front2.sh --instance-type t3.small --associate-public-ip-address --subnet-id ${ID_PUBLIC_SUBNET_2} --key-name ${NOME_CHAVE} --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":10, "VolumeType":"gp3","DeleteOnTermination":true}}]' --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NOME_EC2_PUBLICA_F2}}]" --query 'Instances[0].InstanceId' --output text)
echo "instancia pública criada com sucesso $ID_INSTANCIA_PUBLICA_F2"

echo "criando ip elastico para a instancia pública f2"
ID_IP_F2=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --region us-east-1 --output text)
echo "ip criado"

while true; do
	ESTADO_INSTANCIA=$(aws ec2 describe-instances --instance-ids ${ID_INSTANCIA_PUBLICA_F2} --query 'Reservations[*].Instances[*].State.Name' --output text --region us-east-1)
	if [ "$ESTADO_INSTANCIA" == "running" ]; then
		echo "Instancia Publica Rodando f2"
		echo "associando os dois"
		aws ec2 associate-address --instance-id ${ID_INSTANCIA_PUBLICA_F2} --allocation-id ${ID_IP_F2} --region us-east-1
		break
	fi
	sleep 5
done

echo "tentando rodar instancia privada"
ID_INSTANCIA_PRIVADA=$(aws ec2 run-instances --image-id ami-0360c520857e3138f --region us-east-1 --count 1 --security-group-ids ${ID_GRUPO} --instance-type t3.medium --no-associate-public-ip-address --subnet-id ${ID_PRIVATE_SUBNET} --key-name ${NOME_CHAVE} --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":10, "VolumeType":"gp3","DeleteOnTermination":true}}]' --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NOME_EC2_PRIVADA}}]" --query 'Instances[0].InstanceId' --output text)
echo "instancia privada criada"

echo "criando ip para nat gateway"
ID_IP_NAT=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
echo "IP criado"

echo "criando nat gateway"
ID_NAT=$(aws ec2 create-nat-gateway --subnet-id $ID_PUBLIC_SUBNET --allocation-id $ID_IP_NAT --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=nat-gateway-cafeteria}]' --query 'NatGateway.NatGatewayId' --output text)
echo "nat gtw criado $ID_NAT"

while true; do
    ESTADO_NAT=$(aws ec2 describe-nat-gateways --nat-gateway-ids $ID_NAT --query 'NatGateways[0].State' --output text)
    if [ "$ESTADO_NAT" == "available" ]; then
        echo "NAT ficou available"
        break
    fi
    sleep 5
done

IP_PRIVADO_F1=$(aws ec2 describe-instances --instance-ids ${ID_INSTANCIA_PUBLICA_F1} \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text --region us-east-1)

IP_PRIVADO_F2=$(aws ec2 describe-instances --instance-ids ${ID_INSTANCIA_PUBLICA_F2} \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text --region us-east-1)

echo "criando application load balancer"
ID_ALB=$(aws elbv2 create-load-balancer \
    --name alb-cafeteria \
    --subnets $ID_PUBLIC_SUBNET $ID_PUBLIC_SUBNET_2 \
    --security-groups $ID_GRUPO \
    --scheme internet-facing \
    --type application \
    --tags Key=Name,Value=alb-cafeteria \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)
echo "ALB criado $ID_ALB"

echo "criando target group"
ID_TG=$(aws elbv2 create-target-group \
    --name tg-cafeteria \
    --protocol HTTP \
    --port 80 \
    --vpc-id $ID_VPC \
    --target-type instance \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
echo "Target Group criado $ID_TG"

echo "registrando instancias front1 e front2 no target group"
aws elbv2 register-targets --target-group-arn $ID_TG \
    --targets Id=$ID_INSTANCIA_PUBLICA_F1 Id=$ID_INSTANCIA_PUBLICA_F2
echo "instancias registradas"

echo "criando listener para o ALB"
aws elbv2 create-listener \
    --load-balancer-arn $ID_ALB \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$ID_TG --output text
echo "listener criado"

echo "criando rt privada"
ID_RT_PRIVADA=$(aws ec2 create-route-table --vpc-id $ID_VPC --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rt-privada}]' --query 'RouteTable.RouteTableId' --output text)
echo "rt privada criada $ID_RT_PRIVADA"

echo "criar rota para nat"
aws ec2 create-route --route-table-id $ID_RT_PRIVADA --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $ID_NAT
echo "rta criada para nat"

echo "associando rt a subnet"
aws ec2 associate-route-table --subnet-id $ID_PRIVATE_SUBNET --route-table-id $ID_RT_PRIVADA
echo "associadas com sucesso"

echo "Criando buckets"
aws s3api create-bucket --bucket raw-${NOME_BUCKET}
aws s3api create-bucket --bucket trusted-${NOME_BUCKET}
aws s3api create-bucket --bucket client-${NOME_BUCKET}
echo "Buckets criados"

echo "permitindo acesso externo aos buckets"
aws s3api put-public-access-block \
    --bucket raw-${NOME_BUCKET} \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

aws s3api put-public-access-block \
    --bucket trusted-${NOME_BUCKET} \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

aws s3api put-public-access-block \
    --bucket client-${NOME_BUCKET} \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
echo "acesso permitido"

echo "adicionando politica de acesso aos buckets"
aws s3api put-bucket-policy --bucket raw-${NOME_BUCKET} --policy file://politica_raw.json

aws s3api put-bucket-policy --bucket trusted-${NOME_BUCKET} --policy file://politica_trusted.json

aws s3api put-bucket-policy --bucket client-${NOME_BUCKET} --policy file://politica_client.json
echo "politica adicionada"
