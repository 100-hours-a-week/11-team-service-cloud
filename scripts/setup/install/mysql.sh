#!/bin/bash

if command -v mysql &> /dev/null && mysql --version 2>&1 | grep -q "${MYSQL_VERSION}"; then
  echo "=== MySQL ${MYSQL_VERSION} 이미 설치됨 (스킵) ==="
  return 0
fi

echo "=== MySQL APT 저장소 추가 ==="
wget https://dev.mysql.com/get/mysql-apt-config_0.8.36-1_all.deb
echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.36-1_all.deb
rm -f mysql-apt-config_0.8.36-1_all.deb
sudo apt update

echo "=== MySQL ${MYSQL_VERSION} 설치 ==="
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  mysql-community-server \
  mysql-community-client
sudo systemctl enable mysql
sudo systemctl start mysql
