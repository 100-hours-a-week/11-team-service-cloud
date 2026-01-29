# AMI

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}


# EC2 인스턴스 생성

resource "aws_instance" "bigbang_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = var.subnet_id
  key_name               = "kateboo-11team"
  vpc_security_group_ids = [var.security_group_id]
  ipv6_address_count     = 1
  iam_instance_profile   = var.iam_instance_profile_name

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
    apt-get install -y make wget unzip

    # AWS CLI v2 설치
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip

    # GitHub develop 브랜치 다운로드
    cd /home/ubuntu
    wget https://github.com/100-hours-a-week/11-team-service-cloud/archive/refs/heads/develop.tar.gz
    tar -xzf develop.tar.gz

    # Parameter Store에서 .env 파일 가져오기
    echo "=== Fetching .env from Parameter Store ==="
    /usr/local/bin/aws ssm get-parameter \
      --name "/bigbang/dot-env" \
      --with-decryption \
      --region ap-northeast-2 \
      --query 'Parameter.Value' \
      --output text > /tmp/temp-env
    mv /tmp/temp-env /home/ubuntu/11-team-service-cloud-develop/.env

    # 소유권 변경
    chown -R ubuntu:ubuntu /home/ubuntu/11-team-service-cloud-develop

    # 전체 환경 세팅
    cd /home/ubuntu/11-team-service-cloud-develop
    make setup-all
  EOF

  tags = {
    Name = "bigbang_instance"
  }
}