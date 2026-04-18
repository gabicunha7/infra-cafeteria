#!/bin/bash
apt-get update -y
apt-get install -y nginx

# Página HTML personalizada
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Front 1</title>
</head>
<body style="background-color:lightblue; text-align:center;">
    <h1>Bem vindo ao Servidor Front 1</h1>
    <p>Você está na instância 1</p>
</body>
</html>
EOF

systemctl restart nginx
systemctl enable nginx

