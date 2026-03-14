
#!/bin/bash

NOME_CHAVE=meupardechaves
NOME_GRUPO=meugrupodeseguranca
NOME_EC2_PUBLICA=ec2-publica-front
NOME_EC2_PRIVADA=ec2-privada-back

echo "criando a vpc"
ID_VPC=$(aws ec2 create-vpc --cidr-block 10.0.0.0/24 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=vpc-cafeteria}]' --query 'Vpc.VpcId' --output text)

echo "criando internet gateway"
ID_IGW=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-cafeteria}]' --query 'InternetGateway.InternetGatewayId' --output text)
echo "internet gateway criado"

echo "associando IGW a VPC"
aws ec2 attach-internet-gateway --vpc-id $ID_VPC --internet-gateway-id $ID_IGW
echo "associados"

echo "criando subnet pública"
ID_PUBLIC_SUBNET=$(aws ec2 create-subnet --vpc-id $ID_VPC --cidr-block 10.0.1.0/26 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=subnet-publica}]' --query 'Subnet.SubnetId' --output text)
echo "subnet pública criada $ID_PUBLIC_SUBNET"

echo "criando subnet privada"
ID_PRIVATE_SUBNET=$(aws ec2 create-subnet --vpc-id $ID_VPC --cidr-block 10.0.2.0/26 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=subnet-privada}]' --query 'Subnet.SubnetId' --output text)
echo "subnet privada criada $ID_PRIVATE_SUBNET"

echo "criando rt pÚblica"
ID_RT_PUBLICA=$(aws ec2 create-route-table --vpc-id $ID_VPC --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rt-publica}]' --query 'RouteTable.RouteTableId' --output text)
echo "rt pública criada $ID_RT_PUBLICA"

echo "criando rota para igw"
aws ec2 create-route --route-table-id $ID_RT_PUBLICA --destination-cidr-block 0.0.0.0/0 --gateway-id $ID_IGW
echo "criada"

echo "associando igw a rota"
aws ec2 associate-route-table --subnet-id $ID_PUBLIC_SUBNET --route-table-id $ID_RT_PUBLICA
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

echo "tentando rodar instancia pública"
ID_INSTANCIA_PUBLICA=$(aws ec2 run-instances --image-id ami-0360c520857e3138f --region us-east-1 --count 1 --security-group-ids ${ID_GRUPO} --instance-type t3.small --associate-public-ip-address --subnet-id ${ID_PUBLIC_SUBNET} --key-name ${NOME_CHAVE} --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":10, "VolumeType":"gp3","DeleteOnTermination":true}}]' --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NOME_EC2_PUBLICA}}]" --query 'Instances[0].InstanceId' --output text)
echo "instancia pública criada com sucesso $ID_INSTANCIA_PUBLICA"

echo "criando ip elastico para a instancia pública"
ID_IP=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --region us-east-1 --output text)
echo "ip criado"

while true; do
	ESTADO_INSTANCIA=$(aws ec2 describe-instances --instance-ids ${ID_INSTANCIA_PUBLICA} --query 'Reservations[*].Instances[*].State.Name' --output text --region us-east-1)
	if [ "$ESTADO_INSTANCIA" == "running" ]; then
		echo "Instancia Publica Rodando"
		echo "associando os dois"
		aws ec2 associate-address --instance-id ${ID_INSTANCIA_PUBLICA} --allocation-id ${ID_IP} --region us-east-1
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

echo "criando rt privada"
ID_RT_PRIVADA=$(aws ec2 create-route-table --vpc-id $ID_VPC --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rt-privada}]' --query 'RouteTable.RouteTableId' --output text)
echo "rt privada criada $ID_RT_PRIVADA"

echo "criar rota para nat"
aws ec2 create-route --route-table-id $ID_RT_PRIVADA --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $ID_NAT
echo "rta criada para nat"

echo "associando rt a subnet"
aws ec2 associate-route-table --subnet-id $ID_PRIVATE_SUBNET --route-table-id $ID_RT_PRIVADA
echo "associadas com sucesso"


