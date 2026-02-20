terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.82.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }

  backend "s3" {
    bucket         = "<YOUR_TERRAFORM_STATE_BUCKET>"
    key            = "dev/terraform.tfstate"
    region         = "<YOUR_AWS_REGION>"
    dynamodb_table = "<YOUR_TERRAFORM_LOCK_TABLE>"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
