# A Lambda é implantada pelo próprio repositório (Lambda.Itau); aqui só é referenciada.
# O alias é o mesmo da esteira da Lambda: dev, hom ou prod.
data "aws_lambda_function" "bff" {
  function_name = var.lambda_function_name
  qualifier     = var.stage_name
}

# A implementação STS e a layer permissions.json são geridas pelo módulo corporativo do Itaú.
data "aws_lambda_function" "sts_authorizer" {
  function_name = var.sts_authorizer_function_name
}

# Role de invocação mostrada no security scheme do Itaú; não é a role de execução da função.
data "aws_iam_role" "sts_authorizer_invoke" {
  name = var.sts_authorizer_invoke_role_name
}

locals {
  privada = var.endpoint_type == "PRIVATE"
}

# A origem é configurada nos dois repositórios; se divergir, o preflight passa e o navegador
# bloqueia a resposta da Lambda. Só avisa no plan, não bloqueia.
check "cors_igual_ao_da_lambda" {
  assert {
    condition     = try(data.aws_lambda_function.bff.environment[0].variables["CORS_ALLOWED_ORIGIN"], "") == var.cors_allowed_origin
    error_message = "A env CORS_ALLOWED_ORIGIN da Lambda difere de cors_allowed_origin."
  }
}

# Rotas, integrações e gateway responses vêm do OpenAPI: rode `npm run bundle` antes do plan e do apply.
resource "aws_api_gateway_rest_api" "bff" {
  name = var.api_name
  body = templatefile("${path.module}/../dist/openapi.json", {
    lambda_invoke_arn              = data.aws_lambda_function.bff.qualified_invoke_arn
    cors_allowed_origin            = var.cors_allowed_origin
    sts_authorizer_credentials_arn = data.aws_iam_role.sts_authorizer_invoke.arn
    sts_authorizer_invoke_arn      = data.aws_lambda_function.sts_authorizer.invoke_arn
  })

  # overwrite apaga do API Gateway o que saiu do OpenAPI, mas em API privada também
  # derruba a associação com os VPC endpoints; por isso merge (recomendação do provider).
  put_rest_api_mode = local.privada ? "merge" : "overwrite"

  endpoint_configuration {
    types            = [var.endpoint_type]
    vpc_endpoint_ids = local.privada ? var.vpc_endpoint_ids : null
  }
}

# API privada só aceita chamadas que chegam pelos VPC endpoints informados.
resource "aws_api_gateway_rest_api_policy" "privada" {
  count       = local.privada ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.bff.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.bff.execution_arn}/*"
        Condition = { StringNotEquals = { "aws:SourceVpce" = var.vpc_endpoint_ids } }
      },
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.bff.execution_arn}/*"
      },
    ]
  })
}

resource "aws_api_gateway_deployment" "bff" {
  depends_on  = [aws_lambda_permission.api_gateway]
  rest_api_id = aws_api_gateway_rest_api.bff.id

  # Novo deployment a cada mudança no OpenAPI ou na policy; sem isso o stage segue na versão antiga.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.bff.body,
      aws_api_gateway_rest_api_policy.privada[*].policy,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "acesso" {
  name              = "/aws/api-gateway/${var.api_name}/${var.stage_name}"
  retention_in_days = var.access_log_retention_days
}

resource "aws_api_gateway_stage" "bff" {
  rest_api_id   = aws_api_gateway_rest_api.bff.id
  deployment_id = aws_api_gateway_deployment.bff.id
  stage_name    = var.stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.acesso.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      resourcePath       = "$context.resourcePath"
      status             = "$context.status"
      responseLatency    = "$context.responseLatency"
      integrationStatus  = "$context.integration.status"
      integrationLatency = "$context.integration.latency"
      errorMessage       = "$context.error.message"
      responseType       = "$context.error.responseType"
      integrationError   = "$context.integrationErrorMessage"
      vpceId             = "$context.identity.vpceId"
    })
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGateway-${var.api_name}"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.bff.function_name
  qualifier     = var.stage_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.bff.execution_arn}/${var.stage_name}/*"
}
