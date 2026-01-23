#!/bin/bash

echo "=== MySQL APT 저장소 추가 ==="
wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.33-1_all.deb
echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.33-1_all.deb
rm -f mysql-apt-config_0.8.33-1_all.deb
sudo apt update

echo "=== MySQL ${MYSQL_VERSION} 설치 ==="
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  mysql-community-server=${MYSQL_VERSION}-1ubuntu$(lsb_release -rs) \
  mysql-community-client=${MYSQL_VERSION}-1ubuntu$(lsb_release -rs)
sudo systemctl enable mysql
sudo systemctl start mysql
