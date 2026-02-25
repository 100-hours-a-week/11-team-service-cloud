# Security groups for ALB / instances / RDS

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # (public ALB) Only 80/443 are exposed.
  # (moved) internal service ports are handled by internal ALB SG

  # (moved) internal service ports are handled by internal ALB SG

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name_prefix}-alb-sg"
    Environment = var.environment
  }
}

# Internal ALB security group (for private service-to-service traffic)
resource "aws_security_group" "internal_alb" {
  name        = "${var.name_prefix}-internal-alb-sg"
  description = "Internal ALB security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from within VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name_prefix}-internal-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-web-sg"
  description = "Web instances security group"
  vpc_id      = aws_vpc.this.id

  # Allow ALB -> web
  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Optional: SSH (only if you still use SSH). SSM is preferred.
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name_prefix}-web-sg"
    Environment = var.environment
  }
}

# App (Spring)
resource "aws_security_group" "app_spring" {
  name        = "${var.name_prefix}-app-spring-sg"
  description = "Spring app instances security group"
  vpc_id      = aws_vpc.this.id

  # Allow internal ALB -> spring (8080)
  ingress {
    description     = "8080 from internal ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }

  # Optional: keep direct web -> spring access if you still need it.
  ingress {
    description     = "8080 from web"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name_prefix}-app-spring-sg"
    Environment = var.environment
  }
}

# App (AI)
resource "aws_security_group" "app_ai" {
  name        = "${var.name_prefix}-app-ai-sg"
  description = "AI app instances security group"
  vpc_id      = aws_vpc.this.id

  # Allow internal ALB -> ai (8000)
  ingress {
    description     = "8000 from internal ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }

  # Keep spring -> ai (8000) if the spring service calls AI directly.
  ingress {
    description     = "8000 from spring"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.app_spring.id]
  }

  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name_prefix}-app-ai-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "MySQL from spring and ai"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_spring.id, aws_security_group.app_ai.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name_prefix}-rds-sg"
    Environment = var.environment
  }
}
