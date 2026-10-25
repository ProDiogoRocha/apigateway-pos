# itau-ln-infra-bff-posicao-apigateway

API Gateway REST do BFF de posição. O front chama o API Gateway, que repassa cada rota para a
Lambda `Itau.LN.App.Bff.Posicao` (integração proxy). O preflight CORS (`OPTIONS`) é respondido
pelo próprio API Gateway, sem invocar a Lambda.

## Rotas

As 8 rotas da Lambda estão em `itau-ln-infra-bff-posicao-apigateway.yaml`, que é o contrato.
Todas exigem os headers `x-itau-apikey` e `x-itau-correlationID` (400 se ausentes) e aceitam
`?transportadora=` e o header `chave-unica`.

Erros saem no formato da Lambda, `{ "messages": [{ "codigo", "mensagem" }] }`, inclusive os
gerados pelo API Gateway: 404 (rota inexistente), 429, 502 e 504. Os demais erros do API Gateway
(ex.: 403 da API privada) mantêm o corpo da AWS, `{ "message": "..." }`.

## Estrutura

- `itau-ln-infra-bff-posicao-apigateway.yaml`: OpenAPI raiz.
- `parameters/`, `requestBodies/`, `responses/`, `schemas/`, `examples/`: componentes usados via `$ref`.
- `extensions/`: extensões `x-amazon-apigateway-*` (proxy para a Lambda, mock do preflight, gateway responses).
- `infra/`: Terraform da REST API, deployment, stage com access log e permissão de invocação da Lambda.
- `tests/`: contrato OpenAPI x rotas da Lambda. `infra/tests/`: Terraform com provider simulado.

## Validar

```
npm ci
npm run lint
npm test
terraform -chdir=infra init -backend=false
npm run test:infra
```

## Deploy

Ordem: Lambda (com `CORS_ALLOWED_ORIGIN`), depois este API Gateway, depois o front apontando
para `invoke_url`. Rollback: reverter o commit e rodar a pipeline de novo, na ordem inversa.

O Terraform lê `dist/openapi.json` no plan e no apply, então o bundle vem antes dos dois (ou
`dist/` vai como artefato entre os jobs):

```
npm ci && npm run bundle
cd infra
terraform init -backend-config=<config da pipeline>
terraform apply -var lambda_function_name=<nome da Lambda> -var cors_allowed_origin=https://<front>
```

| Variável | Padrão | Uso |
|---|---|---|
| `lambda_function_name` | obrigatória | Lambda que recebe as requisições |
| `cors_allowed_origin` | obrigatória | origem do front; a mesma da env `CORS_ALLOWED_ORIGIN` da Lambda |
| `api_name` | `itau-ln-bff-posicao` | nome da REST API |
| `stage_name` | `v1` | stage (primeiro segmento da URL) |
| `endpoint_type` | `REGIONAL` | `REGIONAL` ou `PRIVATE` |
| `vpc_endpoint_ids` | `[]` | obrigatório com `PRIVATE` |
| `access_log_retention_days` | `30` | retenção do access log |
| `tags` | `{}` | tags de todos os recursos |

Saídas: `rest_api_id` e `invoke_url`. O que falta para produção está em
[AJUSTES_PENDENTES_POSICAO.md](AJUSTES_PENDENTES_POSICAO.md).
