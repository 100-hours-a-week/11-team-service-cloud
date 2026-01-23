#!/bin/bash

echo "=== Java ${JDK_VERSION} 설치 ==="
sudo apt install -y openjdk-${JDK_VERSION}-jdk

echo "=== unzip 설치 ==="
sudo apt install -y unzip

echo "=== Gradle 설치 ==="
wget -q https://services.gradle.org/distributions/gradle-8.14.3-bin.zip
sudo unzip -o gradle-8.14.3-bin.zip -d /opt/gradle
rm -f gradle-8.14.3-bin.zip
echo 'export PATH=/opt/gradle/gradle-8.14.3/bin:$PATH' >> ~/.bashrc
export PATH=/opt/gradle/gradle-8.14.3/bin:$PATH
