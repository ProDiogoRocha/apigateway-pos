# Recuperacao do template corporativo fotografado em 29/10/2026 (revisao exibida: 0b0a49f).
# Preserva os nomes dos modulos e suas versoes. Nao importa o OpenAPI pelo Terraform local.
module "custom_domain_name" {
  source = "git::https://github.com/itau-corp/itau-dy9-modules-custom-domain-name?ref=v1.2.2"

  api_gateway_domain_name                 = var.api_gateway_domain_name
  api_gateway_domain_name_certificate_arn = data.aws_acm_certificate.certificate.arn

  tags = {
    "map-migrated" = "mig2PGTYAWDWG"
  }
}

module "api_gateway" {
  source = "git::https://github.com/itau-corp/itau-dy9-modules-rest-api?ref=v1.10.2"

  api_gateway_rest_api_name          = var.api_gateway_rest_api_name
  api_gateway_stage_name             = var.environment
  api_gateway_stage_variables        = var.api_gateway_stage_variables
  api_gateway_cloudwatch_role_name   = var.api_gateway_cloudwatch_role_name
  api_gateway_endpoint_configuration = var.api_gateway_endpoint_configuration

  tags = {
    "github_repo_name" = var.github_repo_name
    "github_repo_id"   = var.github_repo_id
    "map-migrated"     = "mig2PGTYAWDWG"
  }

  api_gateway_domain_name = var.api_gateway_domain_name
  api_gateway_api_mapping = var.api_gateway_api_mapping

  depends_on = [module.custom_domain_name]
}

module "lambda_authorizer" {
  source = "git::https://github.com/itau-corp/itau-dy9-modules-lambda-authorizer?ref=v3.3.0"

  lambda_authorizer_function_name = var.lambda_authorizer_function_name
  lambda_authorizer_iam_role_name = var.lambda_authorizer_iam_role_name
  lambda_authorizer_s3_bucket     = var.lambda_authorizer_s3_bucket

  github_repo_name = var.github_repo_name
  github_repo_id   = var.github_repo_id

  lambda_authorizer_kms_key_alias = var.lambda_authorizer_kms_key_alias
  create_kms                      = true

  lambda_authorizer_environment_vars       = var.lambda_authorizer_environment_vars
  lambda_authorizer_permissions_layer_name = var.lambda_authorizer_permissions_layer_name
  lambda_authorizer_subnet_id_list         = var.aws_subnet_id_list
  lambda_authorizer_vpc_id                 = var.aws_vpc_id
  lambda_authorizer_vpc_cidr_list          = var.aws_vpc_cidr_list

  tags = {
    "map-migrated" = "mig2PGTYAWDWG"
  }
}
