
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

cat > lb.sh <<EOF
#!/bin/bash
apt-get update -y
apt-get install -y nginx

cat > /etc/nginx/sites-available/default <<EOL
upstream backend {
    server ${IP_PRIVADO_F1}:80;
    server ${IP_PRIVADO_F2}:80;
}

server {
    listen 80;

    location / {
        proxy_pass http://backend;
    }
}
EOL

systemctl restart nginx
systemctl enable nginx
EOF

echo "tentando rodar instancia pública load balancer"
ID_INSTANCIA_PUBLICA_LB=$(aws ec2 run-instances --image-id ami-0360c520857e3138f --region us-east-1 --count 1 --user-data file://lb.sh --security-group-ids ${ID_GRUPO} --instance-type t3.small --associate-public-ip-address --subnet-id ${ID_PUBLIC_SUBNET} --key-name ${NOME_CHAVE} --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":10, "VolumeType":"gp3","DeleteOnTermination":true}}]' --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NOME_EC2_PUBLICA_LB}}]" --query 'Instances[0].InstanceId' --output text)
echo "instancia pública criada com sucesso $ID_INSTANCIA_PUBLICA_LB"

echo "criando ip elastico para a instancia pública do load balancer"
ID_IP_LB=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --region us-east-1 --output text)
echo "ip criado"

while true; do
	ESTADO_INSTANCIA=$(aws ec2 describe-instances --instance-ids ${ID_INSTANCIA_PUBLICA_LB} --query 'Reservations[*].Instances[*].State.Name' --output text --region us-east-1)
	if [ "$ESTADO_INSTANCIA" == "running" ]; then
		echo "Instancia Publica do load balancer Rodando"
		echo "associando os dois"
		aws ec2 associate-address --instance-id ${ID_INSTANCIA_PUBLICA_LB} --allocation-id ${ID_IP_LB} --region us-east-1
		break
	fi
	sleep 5
done

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
