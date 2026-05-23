#!/bin/bash
exec > /var/log/userdata.log 2>&1
set -x
apt update -y
apt install -y nfs-common nginx
systemctl stop nginx

sleep 120

mkdir -p /var/www/html

for i in $(seq 1 15); do
  if mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-0cc29b6dafc99a4b7.efs.us-east-1.amazonaws.com:/ /var/www/html; then
    printf '%s\n' "fs-0cc29b6dafc99a4b7.efs.us-east-1.amazonaws.com:/ /var/www/html nfs4 defaults,_netdev 0 0" | tee -a /etc/fstab > /dev/null
    break
  fi
  sleep 20
done

if ! mountpoint -q /var/www/html; then
  exit 1
fi

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
printf '%s' "PCFET0NUWVBFIGh0bWw+CjxodG1sPgo8aGVhZD48bWV0YSBjaGFyc2V0PSJVVEYtOCI+PHRpdGxlPkNhZmV0ZXJpYTwvdGl0bGU+PC9oZWFkPgo8Ym9keT48aDE+QXBsaWNhY2FvIFdlYiBDYWZldGVyaWE8L2gxPjwvYm9keT4KPC9odG1sPg==" | base64 -d > /var/www/html/index.html

chown www-data:www-data /var/www/html/index.html
chmod 644 /var/www/html/index.html
systemctl start nginx
systemctl enable nginx
