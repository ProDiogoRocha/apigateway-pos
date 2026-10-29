variable "api_name" {
  description = "Nome da REST API no API Gateway."
  type        = string
  default     = "api-posicao-custodia-numerario"
}

variable "stage_name" {
  description = "Stage do ambiente e alias da Lambda publicados pela esteira do Itaú."
  type        = string

  validation {
    condition     = contains(["dev", "hom", "prod"], var.stage_name)
    error_message = "stage_name deve ser dev, hom ou prod (igual ao alias da Lambda)."
  }
}

variable "lambda_function_name" {
  description = "Nome da Lambda Itau.LN.App.Bff.Posicao que recebe as requisições."
  type        = string
}

variable "cors_allowed_origin" {
  description = "Origem do front liberada no CORS (ex.: https://front.exemplo.com). Deve ser igual ao CORS_ALLOWED_ORIGIN da Lambda."
  type        = string

  # O navegador compara a origem exata (esquema://host[:porta], host em minúsculas); barra ou
  # caminho nunca casam, e aspas quebram o JSON do OpenAPI.
  validation {
    condition     = can(regex("^(\\*|https?://[a-z0-9.-]+(:[0-9]{1,5})?)$", var.cors_allowed_origin))
    error_message = "Use \"*\" ou uma origem https://host[:porta] em minúsculas, sem caminho nem barra final."
  }
}

variable "endpoint_type" {
  description = "REGIONAL ou PRIVATE (acesso só via VPC endpoint)."
  type        = string
  default     = "PRIVATE"

  validation {
    condition     = contains(["REGIONAL", "PRIVATE"], var.endpoint_type)
    error_message = "endpoint_type deve ser REGIONAL ou PRIVATE."
  }
}

variable "vpc_endpoint_ids" {
  description = "VPC endpoints (execute-api) autorizados quando endpoint_type = PRIVATE."
  type        = list(string)
  default     = []

  validation {
    condition     = var.endpoint_type != "PRIVATE" || length(var.vpc_endpoint_ids) > 0
    error_message = "Informe ao menos um vpc_endpoint_id quando endpoint_type = PRIVATE."
  }
}

variable "access_log_retention_days" {
  description = "Retenção dos logs de acesso do stage, em dias."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags aplicadas aos recursos."
  type        = map(string)
  default     = {}
}

variable "sts_authorizer_function_name" {
  description = "Lambda STS criada pelo módulo itau-dy9-modules-lambda-authorizer (nome visto na tfvars de dev)."
  type        = string
  default     = "valida-token-posicao-custodia-numerario-v1-interno"
}

variable "sts_authorizer_invoke_role_name" {
  description = "Role que o API Gateway assume para invocar o authorizer (vista no security scheme do Itaú)."
  type        = string
  default     = "custom-gateway-invoke-authorizer-role"
}
