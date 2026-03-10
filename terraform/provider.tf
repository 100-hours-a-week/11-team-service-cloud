terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }

  required_version = ">= 1.14.3"

  backend "s3" {
    bucket         = "scuad-tfstate-ap-northeast-2"
    key            = "v1/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "scuad-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}
