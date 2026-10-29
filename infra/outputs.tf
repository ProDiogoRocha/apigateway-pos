output "rest_api_id" {
  description = "ID da REST API."
  value       = aws_api_gateway_rest_api.bff.id
}

output "invoke_url" {
  description = "URL execute-api do stage dev/hom/prod; não inclui domínio ou mapping corporativo."
  value       = aws_api_gateway_stage.bff.invoke_url
}
