terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Configurado pela pipeline: terraform init -backend-config=...
  backend "s3" {}
}

# Região e credenciais vêm do ambiente (AWS_REGION, perfil ou role da pipeline).
provider "aws" {
  default_tags {
    tags = var.tags
  }
}
