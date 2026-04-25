#!/bin/bash
apt-get update -y
apt-get install -y nginx

cat > /etc/nginx/sites-available/default <<EOL
upstream backend {
    server 10.0.0.18:80;
    server 10.0.0.155:80;
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
