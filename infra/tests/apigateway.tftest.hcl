# Provider simulado: nada é criado na AWS. Requer o bundle (npm run bundle).
mock_provider "aws" {
  # O provider valida o formato dos ARNs; valores aleatórios do mock não passam.
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:sa-east-1:123456789012:log-group:/aws/api-gateway/teste"
    }
  }

  mock_resource "aws_api_gateway_rest_api" {
    defaults = {
      execution_arn = "arn:aws:execute-api:sa-east-1:123456789012:abc123"
    }
  }

  mock_resource "aws_api_gateway_stage" {
    defaults = {
      execution_arn = "arn:aws:execute-api:sa-east-1:123456789012:abc123/v1"
    }
  }

  mock_data "aws_lambda_function" {
    defaults = {
      invoke_arn  = "arn:aws:apigateway:sa-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:sa-east-1:123456789012:function:itau-ln-bff-posicao/invocations"
      environment = [{ variables = { CORS_ALLOWED_ORIGIN = "https://front.exemplo.com" } }]
    }
  }
}

variables {
  lambda_function_name = "itau-ln-bff-posicao"
  cors_allowed_origin  = "https://front.exemplo.com"
}

run "regional_publica_o_openapi_com_a_lambda_e_o_cors" {
  command = apply

  assert {
    condition     = strcontains(aws_api_gateway_rest_api.bff.body, data.aws_lambda_function.bff.invoke_arn)
    error_message = "As integrações devem apontar para a Lambda."
  }

  assert {
    condition     = strcontains(aws_api_gateway_rest_api.bff.body, "'https://front.exemplo.com'")
    error_message = "O CORS deve usar a origem informada."
  }

  assert {
    condition     = can(jsondecode(aws_api_gateway_rest_api.bff.body))
    error_message = "O OpenAPI preenchido deve continuar sendo JSON válido."
  }

  assert {
    condition     = aws_api_gateway_rest_api.bff.put_rest_api_mode == "overwrite" && length(aws_api_gateway_rest_api_policy.privada) == 0
    error_message = "API regional não tem resource policy e sobrescreve o OpenAPI."
  }

  assert {
    condition = (
      aws_lambda_permission.api_gateway.principal == "apigateway.amazonaws.com" &&
      aws_lambda_permission.api_gateway.function_name == "itau-ln-bff-posicao" &&
      aws_lambda_permission.api_gateway.source_arn == "arn:aws:execute-api:sa-east-1:123456789012:abc123/v1/*"
    )
    error_message = "Só o stage deste API Gateway pode invocar a Lambda."
  }
}

run "cors_diferente_do_da_lambda_gera_aviso" {
  command = apply

  override_data {
    target = data.aws_lambda_function.bff
    values = {
      environment = [{ variables = { CORS_ALLOWED_ORIGIN = "https://outro.exemplo.com" } }]
    }
  }

  expect_failures = [check.cors_igual_ao_da_lambda]
}

run "privada_so_aceita_os_vpc_endpoints" {
  command = apply

  variables {
    endpoint_type    = "PRIVATE"
    vpc_endpoint_ids = ["vpce-0123456789abcdef0"]
  }

  assert {
    condition     = aws_api_gateway_rest_api.bff.put_rest_api_mode == "merge"
    error_message = "API privada usa merge para não perder os VPC endpoints."
  }

  assert {
    condition = (
      [for s in jsondecode(aws_api_gateway_rest_api_policy.privada[0].policy).Statement : s.Effect] == ["Deny", "Allow"] &&
      jsondecode(aws_api_gateway_rest_api_policy.privada[0].policy).Statement[0].Resource == "arn:aws:execute-api:sa-east-1:123456789012:abc123/*" &&
      jsondecode(aws_api_gateway_rest_api_policy.privada[0].policy).Statement[0].Condition.StringNotEquals["aws:SourceVpce"] == ["vpce-0123456789abcdef0"]
    )
    error_message = "A policy deve negar chamadas fora dos VPC endpoints e liberar as demais."
  }
}

run "privada_sem_vpc_endpoint_e_rejeitada" {
  command = plan

  variables {
    endpoint_type = "PRIVATE"
  }

  expect_failures = [var.vpc_endpoint_ids]
}

run "origem_cors_com_aspas_e_rejeitada" {
  command = plan

  variables {
    cors_allowed_origin = "https://front.exemplo.com'"
  }

  expect_failures = [var.cors_allowed_origin]
}

run "origem_cors_com_barra_final_e_rejeitada" {
  command = plan

  variables {
    cors_allowed_origin = "https://front.exemplo.com/"
  }

  expect_failures = [var.cors_allowed_origin]
}

run "origem_cors_com_aspa_dupla_e_rejeitada" {
  command = plan

  variables {
    cors_allowed_origin = "https://front\".exemplo.com"
  }

  expect_failures = [var.cors_allowed_origin]
}
