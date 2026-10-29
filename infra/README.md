# Terraform de referência local

Esta pasta usa recursos AWS diretos (`aws_api_gateway_rest_api.bff`, stage e
permissões). No Itaú, os arquivos fotografados usam os módulos corporativos
`module.api_gateway`, `module.custom_domain_name` e `module.lambda_authorizer`.
Preserve a infraestrutura corporativa no repositório do banco.

O erro conjunto de `var.api_gateway_domain_name` não declarada em `data.tf`,
`var.environment` não declarada em `iamsr.tf` e `dist/openapi.json` ausente em
`main.tf` é compatível com arquivos das duas implementações no mesmo diretório.
A correção depende de conferir os arquivos atuais do banco; adicionar apenas as
duas variáveis não restaura os módulos corporativos.

Usar os arquivos recuperados em [correcao-itau/infra](../correcao-itau/README.md)
para restaurar main.tf/variables.tf no banco. Ver também o
[roteiro de correção no Itaú](../CORRECAO_TERRAFORM_ITAU.md).

Para executar exclusivamente esta referência local, o bundle deve existir antes
do validate, plan ou apply:

```sh
npm ci
npm run bundle
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
npm run test:infra
```

Esse procedimento local não altera o workflow corporativo nem gera suas variáveis.
