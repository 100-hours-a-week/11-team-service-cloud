provider "aws" {
  region = "ap-northeast-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}


# VPC 생성

resource "aws_vpc" "prod" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true

  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "prod-vpc"
  }
}

# Internet Gateway

resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id
  tags = {
    Name = "prod-igw"
  }
}

# 퍼블릭 서브넷

resource "aws_subnet" "prod_public_a" {
  vpc_id                          = aws_vpc.prod.id
  cidr_block                      = "10.0.1.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.prod.ipv6_cidr_block, 8, 1)
  availability_zone               = "ap-northeast-2a"
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "prod-public-subnet-a"
  }
}

resource "aws_subnet" "prod_public_b" {
  vpc_id                          = aws_vpc.prod.id
  cidr_block                      = "10.0.2.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.prod.ipv6_cidr_block, 8, 2)
  availability_zone               = "ap-northeast-2b"
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "prod-public-subnet-b"
  }
}

# 프라이빗 APP 서브넷

resource "aws_subnet" "prod_app_private_a" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.8.0/21"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "prod-app-private-subnet-a"
  }
}

resource "aws_subnet" "prod_app_private_b" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.16.0/21"
  availability_zone = "ap-northeast-2b"
  tags = {
    Name = "prod-app-private-subnet-b"
  }
}

# 프라이빗 DB 서브넷

resource "aws_subnet" "prod_db_private_a" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "prod-db-private-subnet-a"
  }
}

resource "aws_subnet" "prod_db_private_b" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-2b"
  tags = {
    Name = "prod-db-private-subnet-b"
  }
}

# 퍼블릭 라우트 테이블

resource "aws_route_table" "prod_public" {
  vpc_id = aws_vpc.prod.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod.id
  }
  tags = {
    Name = "prod-public-rt"
  }
}
# 라우트 테이블 연결

resource "aws_route_table_association" "prod_public_a" {
  subnet_id      = aws_subnet.prod_public_a.id
  route_table_id = aws_route_table.prod_public.id
}

resource "aws_route_table_association" "prod_public_b" {
  subnet_id      = aws_subnet.prod_public_b.id
  route_table_id = aws_route_table.prod_public.id
}

# 프라이빗 라우트 테이블 (NAT Gateway 없이 로컬 통신만)

resource "aws_route_table" "prod_private" {
  vpc_id = aws_vpc.prod.id
  tags = {
    Name = "prod-private-rt"
  }
}

resource "aws_route_table_association" "prod_app_private_a" {
  subnet_id      = aws_subnet.prod_app_private_a.id
  route_table_id = aws_route_table.prod_private.id
}

resource "aws_route_table_association" "prod_app_private_b" {
  subnet_id      = aws_subnet.prod_app_private_b.id
  route_table_id = aws_route_table.prod_private.id
}

resource "aws_route_table_association" "prod_db_private_a" {
  subnet_id      = aws_subnet.prod_db_private_a.id
  route_table_id = aws_route_table.prod_private.id
}

resource "aws_route_table_association" "prod_db_private_b" {
  subnet_id      = aws_subnet.prod_db_private_b.id
  route_table_id = aws_route_table.prod_private.id
}

# 보안 그룹

resource "aws_security_group" "ssh" {
  name        = "allow-ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.prod.id

  ingress {
    description = "SSH from IPv4"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH from IPv6"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow-ssh"
  }
}

# EC2 인스턴스 생성

resource "aws_instance" "bigbang_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.prod_public_a.id
  key_name               = "kakaotech-beemo"
  vpc_security_group_ids = [aws_security_group.ssh.id]
  ipv6_address_count     = 1

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # 패키지 설치
    apt-get update
    apt-get install -y make wget

    # GitHub develop 브랜치 다운로드
    cd /home/ubuntu
    wget https://github.com/100-hours-a-week/11-team-service-cloud/archive/refs/heads/develop.tar.gz
    tar -xzf develop.tar.gz
    cd 11-team-service-cloud-develop

    # 소유권 변경
    chown -R ubuntu:ubuntu /home/ubuntu/11-team-service-cloud-develop

    # 전체 환경 세팅
    make setup-all
  EOF

  tags = {
    Name = "bigbang_instance"
  }
}