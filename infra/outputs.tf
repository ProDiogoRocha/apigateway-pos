output "rest_api_id" {
  description = "ID da REST API."
  value       = aws_api_gateway_rest_api.bff.id
}

output "invoke_url" {
  description = "URL base que o front chama (ex.: <invoke_url>/posicao-transportadores)."
  value       = aws_api_gateway_stage.bff.invoke_url
}
