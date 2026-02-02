#!/bin/bash

if command -v java &> /dev/null && java -version 2>&1 | grep -q "\"${JDK_VERSION}\."; then
  echo "=== Java ${JDK_VERSION} 이미 설치됨 (스킵) ==="
else
  echo "=== Java ${JDK_VERSION} 설치 ==="
  sudo apt install -y openjdk-${JDK_VERSION}-jdk
fi

if ! command -v unzip &> /dev/null; then
  echo "=== unzip 설치 ==="
  sudo apt install -y unzip
fi

if command -v gradle &> /dev/null || [ -d /opt/gradle ]; then
  echo "=== Gradle 이미 설치됨 (스킵) ==="
else
  echo "=== Gradle 설치 ==="
  wget https://services.gradle.org/distributions/gradle-8.14.3-bin.zip
  sudo unzip -o gradle-8.14.3-bin.zip -d /opt/gradle
  rm -f gradle-8.14.3-bin.zip
  echo 'export PATH=/opt/gradle/gradle-8.14.3/bin:$PATH' >> ~/.bashrc
fi

export PATH=/opt/gradle/gradle-8.14.3/bin:$PATH
