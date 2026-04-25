#!/bin/bash
apt-get update -y
apt-get install -y nginx

sleep 10

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Front 2</title>
    <meta charset="UTF-8">
</head>
<body style="background-color:lightgreen; text-align:center;">
    <h1>Bem-vindo ao Servidor Front 2</h1>
    <p>Você está na instância 2 de id: $INSTANCE_ID</p>
    <p>IP: $PRIVATE_IP</p>
</body>
</html>
EOF

systemctl restart nginx
systemctl enable nginx
