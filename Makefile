.PHONY: help setup-all setup-source setup-mysql

SHELL := /bin/bash
SETUP_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/setup
BUILD_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/build
DEPLOY_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/deploy

help:
	@echo "사용 가능한 명령어:"
	@echo "  make setup-all     - 전체 환경 세팅 (Git, Nginx, Java, Node, Python, MySQL)"
	@echo "  make setup-source  - 소스코드 클론 및 개발 환경 설치"
	@echo "  make setup-mysql   - MySQL 설치 및 DB/유저 생성"
	@echo "  make build-all     - 서버 빌드"
	@echo "  make deploy-all    - 서버 배포"


setup-all:
	@echo "=== 전체 환경 세팅 시작 ==="
	@chmod +x $(SETUP_DIR)/setup.sh
	@$(SETUP_DIR)/setup.sh

setup-source:
	@echo "=== 소스코드 및 개발 환경 설치 시작 ==="
	@chmod +x $(SETUP_DIR)/setup-source.sh
	@$(SETUP_DIR)/setup-source.sh

setup-mysql:
	@echo "=== MySQL 설치 및 설정 시작 ==="
	@chmod +x $(SETUP_DIR)/setup-mysql.sh
	@$(SETUP_DIR)/setup-mysql.sh

build-all:
	@echo "=== FE + BE + AI 서버 빌드 ==="
	@chmod +x $(BUILD_DIR)/build.sh
	@$(BUILD_DIR)/build.sh

deploy-all:
	@echo "=== FE + BE + AI 서버 배포 ==="
	@chmod +x $(DEPLOY_DIR)/deploy.sh
	@$(DEPLOY_DIR)/deploy.sh