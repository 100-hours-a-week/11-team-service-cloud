# -------------------------
# ECR repositories (shared)
# -------------------------

resource "aws_ecr_repository" "k8s_pause" {
  name                 = "k8s/pause"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}k8s-pause"
  })
}

resource "aws_ecr_lifecycle_policy" "k8s_pause" {
  repository = aws_ecr_repository.k8s_pause.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "k8s_pause_repository_url" {
  value       = aws_ecr_repository.k8s_pause.repository_url
  description = "ECR repository URL for k8s/pause"
}
