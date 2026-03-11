# Optional: publish commonly-used network outputs to SSM Parameter Store
# (kept minimal; extend as needed)

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.project}/v3/network/vpc_id"
  type  = "String"
  value = module.vpc.vpc_id

  tags = {
    Project = var.project
  }
}
