#!/bin/bash
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y git binutils make gcc nginx nfs-common

# Tenta instalar amazon-efs-utils
git clone https://github.com/aws/efs-utils /tmp/efs-utils
cd /tmp/efs-utils
./build-deb.sh
apt-get install -y ./build/amazon-efs-utils*deb || echo "amazon-efs-utils não disponível, usando NFS comum"

systemctl start nginx
systemctl enable nginx

mkdir -p /var/www/html

mount -t nfs4 fs-028d85003f6b456b3.efs.us-east-1.amazonaws.com:/ /var/www/html
echo '<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Cafeteria</title>
</head>
<body>
<h1>Aplicação Web Cafeteria</h1>
</body>
</html>' > /var/www/html/index.html

systemctl restart nginx
