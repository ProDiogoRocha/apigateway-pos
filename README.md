# API Gateway do BFF de posição

O front envia `Authorization: Bearer <token STS>`, `x-itau-apikey` e
`x-itau-correlationID`. O authorizer corporativo valida o STS antes da Lambda BFF.
A Lambda obtém seu próprio token STS para chamar as APIs de destino e gera o JWT HS256
do header `chave-unica` a partir do centralizador. O front não gera esse JWT.

As oito operações do OpenAPI correspondem ao `BffRequestHandler` da Lambda:
sete GET com `numerario-posicao-transportadores.read` e a reversão POST com
`numerario-posicao-transportadores.write`. As quatro operações de posição exigem
`centralizador`, `polo` e `transportadora`; a lista exige também `data`.
`transportadora` é o fornecedor, e não o código da base. Não há consulta ao RDS.

## Requests para testar em dev

A pasta [curl/dev](curl/dev/README.md) contém cURLs individuais para as oito operações,
obtenção do token STS, preflight CORS e uma collection/environment para Postman.
Preencha a URL real e as variáveis de dev conforme o README da pasta.

## Authorizer e erros

`securitySchemes/APIGatewaySTSAuthorizer.yaml` segue o arquivo fotografado no Itaú:
`request`, `method.request.header.authorization`, TTL 0 e a role
`custom-gateway-invoke-authorizer-role`. O tipo foi normalizado de `Request` para
`request`, conforme o formato documentado pela AWS.

Cada operação declara `security` explicitamente. Cada OPTIONS tem `security: []`,
responde por mock e libera `Authorization` no CORS. Os erros 400 de parâmetros,
401, 403, 429, falhas do authorizer, 502 e 504 têm CORS e o envelope da Lambda:
`{"messages":[{"codigo":"401","mensagem":"Nao autorizado."}]}`.

As permissões declaradas no OpenAPI **não implementam** a autorização read/write.
Isso depende do authorizer e do `/opt/permissions.json` da layer corporativa,
cujo conteúdo ainda precisa ser conferido. Com REQUEST e TTL 0, token ausente ou inválido
pode resultar em 401 ou 403, conforme a resposta do authorizer. Os testes locais verificam a configuração;
eles não validam um token STS real.

## Validar localmente

```sh
npm ci
npm run lint
npm test
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
npm run test:infra
```

O bundle em `dist/openapi.json` é um template com quatro placeholders. Gere-o antes
do Terraform. `infra/tests/` usa provider simulado e não cria recursos na AWS.

## Preparar o contrato para copiar ao Itaú

A infraestrutura fotografada já usa os módulos corporativos de REST API, domínio e
authorizer. Preserve esses módulos e seu state. O `infra/` deste repositório é uma
referência com recursos AWS diretos e **não deve substituir** o Terraform do banco.

Gere um OpenAPI independente, sem `$ref` nem placeholders, para cada ambiente:

```sh
npm run bundle:itau -- --environment dev \
  --cors https://ORIGEM-REAL-DO-FRONT \
  --vpce vpce-ID-REAL \
  --base-url https://DOMINIO-REAL/BASE-PATH-REAL
```

Substitua os valores do exemplo pelos reais, em minúsculas. `--base-url` deve ser a
URL completa do BFF, com o mapping efetivamente configurado; não deduza o mapping
somente pelo `servers` da foto. Repita `--vpce` para liberar mais de um endpoint.
Use `--environment hom` ou `prod` para os outros ambientes.

O resultado fica em
`dist/itau/<ambiente>/itau-ln-infra-bff-posicao-apigateway.yaml`.
Ele contém a conta do ambiente, o alias `dev`/`hom`/`prod` da Lambda,
a role `iamsr/invoke-lambda-ln-app-bff-posicao`, o authorizer STS com sua role,
a policy dos VPCEs e o CORS. Os nomes das funções e roles vêm das fotos; confirme
que também existem em hom/prod antes de preparar esses ambientes.

Copie o **conteúdo do artefato gerado** para o OpenAPI que o workflow do banco importa.
Confirme no workflow como ele seleciona/substitui o contrato por ambiente antes de
promover: um artefato gerado para dev contém ARNs de dev e não pode ir a hom/prod.
Não copie o template raiz com placeholders de Terraform diretamente para a esteira.
A lista de arquivos e as pendências estão em [ARQUIVOS_MODIFICADOS.md](ARQUIVOS_MODIFICADOS.md)
e [AJUSTES_PENDENTES_POSICAO.md](AJUSTES_PENDENTES_POSICAO.md).

## Terraform de referência

| Variável | Uso |
|---|---|
| `stage_name` | Obrigatória: `dev`, `hom` ou `prod`; também seleciona o alias da Lambda |
| `lambda_function_name` | Nome da Lambda BFF existente |
| `cors_allowed_origin` | Igual ao `CORS_ALLOWED_ORIGIN` da Lambda |
| `endpoint_type` | `PRIVATE` por padrão; `REGIONAL` disponível para referência |
| `vpc_endpoint_ids` | Obrigatório para API privada |
| `sts_authorizer_function_name` | Padrão: `valida-token-posicao-custodia-numerario-v1-interno` |
| `sts_authorizer_invoke_role_name` | Padrão: `custom-gateway-invoke-authorizer-role` |

O Terraform consulta o alias publicado, usa `qualified_invoke_arn` e permite invocação
nesse alias. Referencia a função e a role STS existentes. Não cria o código do
authorizer, a layer de permissões nem o domínio corporativo.

Saídas: `rest_api_id` e `invoke_url` (URL execute-api, acessível pela rede privada).
A URL do domínio customizado vem da infraestrutura do Itaú.

Referências: [authorizers em OpenAPI](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions-authorizer.html)
e [limitações de importação REST](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-known-issues.html).
