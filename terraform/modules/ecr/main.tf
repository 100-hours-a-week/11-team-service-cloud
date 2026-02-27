resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  force_delete = var.force_delete

  tags = var.tags
}

# Optional: simple lifecycle policy to avoid unbounded image growth.
resource "aws_ecr_lifecycle_policy" "this" {
  count      = var.lifecycle_keep_last == null ? 0 : 1
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire images when more than N images are present"
        selection = {
          tagStatus = "tagged"
          tagPrefixList = [
            "dev-",
            "staging-",
            "prod-",
            "sha-",
            "main-"
          ]
          countType   = "imageCountMoreThan"
          countNumber = var.lifecycle_keep_last
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
