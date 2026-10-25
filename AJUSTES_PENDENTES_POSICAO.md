# Ajustes pendentes: API Gateway Posição

## Arquivos do repositório real que não foram recriados

A foto mostra estes arquivos sem o conteúdo. Copie do repositório real:

- `.github/`, `.stk/`, `.vscode/`, `.iupipes.yml`: pipeline e StackSpot.
- `apm.yml`, `APM.md`: cadastro APM.
- `CATALOGO_CHAMADAS_POSICAO.md`, `CONTRATO_BFF_ECS_FRONT_POSICAO.md`: aqui o contrato é o próprio
  OpenAPI. Confira se os documentos reais divergem dele.
- `securitySchemes/`: removido, porque não há authorizer (ver Segurança).

## Pipeline

- Rodar `npm ci && npm run bundle` antes do `terraform plan` e do `apply`, porque o Terraform lê `dist/openapi.json`.
- O backend S3 vem da pipeline (`terraform init -backend-config=...`).
- A Lambda precisa existir antes do apply (data source `aws_lambda_function`).
- A permissão de invocação (`aws_lambda_permission`) fica na Lambda do outro repositório: a role desta
  pipeline precisa de `lambda:GetFunction`, `lambda:AddPermission` e `lambda:RemovePermission` nela.
  Se a Lambda for recriada, a permissão some e a API responde 500 até reaplicar este Terraform.
- A API chama a Lambda sem versão (`$LATEST`). Para usar um alias: `qualifier` do alias no data
  source, `qualified_invoke_arn` no `templatefile` e `qualifier` no `aws_lambda_permission`.

## Lambda

- Configurar `CORS_ALLOWED_ORIGIN` com o mesmo valor de `cors_allowed_origin`. Sem isso o navegador
  bloqueia as respostas da Lambda (o preflight passa, a chamada real não). O `terraform plan` avisa
  quando os dois divergem (check `cors_igual_ao_da_lambda`).
- Timeout da Lambda em 30s e integração do API Gateway em 29s: uma chamada lenta devolve 504 do
  API Gateway ("Tempo de resposta excedido.") e a Lambda segue até o próprio cancelamento. Para o
  front receber o 500 da Lambda, baixe o timeout dela para 28s (mesmo assim, em cold start o init
  conta nos 29s). O front precisa de timeout HTTP acima de 29s.
- Com domínio customizado, `API_BASE_PATH` da Lambda tem que ser igual ao base path do mapping;
  pela URL `execute-api` o stage não chega no path.

## Segurança

- A Lambda só exige que `x-itau-apikey` esteja presente; o API Gateway não valida chave nem token.
  Se houver authorizer (Lambda ou Cognito) ou API key com usage plan, recrie `securitySchemes/`,
  declare `security` no OpenAPI e religue a regra `security-defined` no `redocly.yaml`.
- Sem WAF, throttling por stage e domínio customizado: vale o limite da conta. Configure conforme o
  padrão da plataforma.
- O access log exige a role do CloudWatch nas configurações de conta do API Gateway
  (`aws_api_gateway_account`), que normalmente é da plataforma. Sem ela, o stage falha no apply.
- A AWS não permite customizar o 413 (`REQUEST_TOO_LARGE`): ele chega ao front sem header CORS.

## API privada

- Com `endpoint_type = PRIVATE` o OpenAPI é aplicado em modo `merge` (para não perder os VPC
  endpoints). Uma rota removida do OpenAPI continua no API Gateway até ser apagada manualmente.
- A `invoke_url` só resolve com DNS privado habilitado no VPC endpoint; sem ele, use
  `https://{api-id}-{vpce-id}.execute-api.{region}.amazonaws.com/{stage}`.
- Defina o tipo de endpoint no primeiro apply de cada ambiente; trocar REGIONAL por PRIVATE numa
  stack existente não foi testado.
