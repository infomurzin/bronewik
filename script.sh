DEPLOY_SCRIPT=$(cat << 'EOSCRIPT'
#1
useradd user1
mkdir /home/user1/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDD8GLB5i...' >> /home/user1/.ssh/authorized_keys
chmod 700 /home/user1/.ssh
chmod 600 /home/user1/.ssh/authorized_keys
chown user1:user1 /home/user1 -R

#2
sed -i "s#^.*PermitRootLogin.*#PermitRootLogin no#g" /etc/ssh/sshd_config
sed -i "s#^.*PasswordAuthentication.*#PasswordAuthentication no#g" /etc/ssh/sshd_config

#3
wget -qO- https://get.docker.com/ | bash

#4
groupadd docker
service docker restart
usermod -a -G docker user1

#5
mkdir -p /home/user1/nginx/conf.d /home/user1/nginx/logs
cat > /home/user1/nginx/conf.d/default.conf << 'EOL'
server {
    listen       80;
    server_name  _;
    access_log  /var/log/nginx/access.log  main;
    location / {
      add_header Content-Type text/plain;
        return 200 'SERVERNAME';
    }
}
EOL
sed -i 's#SERVERNAME#'${SERVER_NAME}'#g' /home/user1/nginx/conf.d/default.conf
docker run -p 80:80 -v /home/user1/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf -v /home/user1/nginx/logs/:/var/log/nginx/ -d nginx

#6
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 22,80,443 -j ACCEPT
iptables -A INPUT -p tcp -j DROP
iptables -A INPUT -p udp -j DROP
EOSCRIPT
)


for SERVER_NUM in {1.97}
do
SERVER_NAME=server${SERVER_NUM}
SERVER_IP=172.16.0.1${SERVER_NUM}

ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SERVER_IP} "bash -s" << EOSSH
SERVER_NAME=${SERVER_NAME}
${DEPLOY_SCRIPT}
EOSSH

done
