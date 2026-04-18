#!/bin/bash
apt-get update -y
apt-get install -y nginx

# Página HTML personalizada
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Front 2</title>
    <meta charset="UTF-8">
</head>
<body style="background-color:lightgreen; text-align:center;">
    <h1>Bem-vindo ao Servidor Front 2</h1>
    <p>Você está na instância F2</p>
</body>
</html>
EOF

systemctl restart nginx
systemctl enable nginx
