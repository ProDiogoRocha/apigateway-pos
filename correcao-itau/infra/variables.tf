# Entradas do template corporativo fotografado; substituir o arquivo de referencia local inteiro.
# Os valores de cada ambiente permanecem nos inventories do banco.
variable "environment" {
  type        = string
  description = "Stage name (dev, hom, or prod)"

  validation {
    condition     = contains(["dev", "hom", "prod"], var.environment)
    error_message = "Allowed values for environment are dev, hom, or prod."
  }
}

variable "aws_vpc_id" {
  type        = string
  description = "VPC ID where the SG of the Lambda will be created"
}

variable "aws_vpc_cidr_list" {
  type        = list(string)
  description = "CIDR of the VPC allowed within the ingress rules of the SG"
}

variable "aws_subnet_id_list" {
  type        = list(string)
  description = "List with the subnet IDs where the Lambda will be deployed"
}

variable "github_repo_id" {
  type        = string
  description = "GitHub repository ID"
  default     = "GITHUB_REPOSITORY_TAG_PLACEHOLDER" # Substituido pelo fluxo corporativo: preservar.
}

variable "github_repo_name" {
  type        = string
  description = "GitHub repository Name"
  default     = "GITHUB_REPOSITORY_NAME" # Substituido pelo fluxo corporativo: preservar.
}

variable "api_gateway_rest_api_name" {
  type        = string
  description = "API Gateway REST API name"
}

variable "api_gateway_stage_variables" {
  type        = map(any)
  description = "Stage variables map"
  default     = {}
}

variable "api_gateway_cloudwatch_role_name" {
  type        = string
  description = "Role para logar"
  default     = "custom-gateway-log-role"
}

variable "api_gateway_endpoint_configuration" {
  type        = string
  description = "API Gateway endpoint configuration"
  default     = "PRIVATE"
}

variable "api_gateway_domain_name" {
  type        = string
  description = "Domain name to forward requests to API Gateway"
  default     = ""
}

variable "api_gateway_api_mapping" {
  type        = string
  description = "Base path to forward requests to API Gateway"
  default     = ""
}

variable "lambda_authorizer_function_name" {
  type        = string
  description = "Lambda authorizer name"

  validation {
    condition     = can(regex("^valida-token-.*", var.lambda_authorizer_function_name))
    error_message = "The lambda_authorizer_function_name value must start with valida-token-."
  }
}

variable "lambda_authorizer_permissions_layer_name" {
  type        = string
  description = "Lambda authorizer layer name"
}

variable "lambda_authorizer_s3_bucket" {
  type        = string
  description = "Bucket codigo Lambda"
  default     = "api4u-files-repo-prod"
}

variable "lambda_authorizer_environment_vars" {
  type        = map(any)
  description = "Lambda authorizer environment variables"
}

variable "lambda_authorizer_iam_role_name" {
  type        = string
  description = "Name of the execution role attached to the Lambda authorizer function"
  default     = "custom-execution-lambda-authorizer-role"
}

variable "lambda_authorizer_kms_key_alias" {
  type        = string
  description = "KMS key alias to encrypt the data on the Lambda"
  default     = ""
}
