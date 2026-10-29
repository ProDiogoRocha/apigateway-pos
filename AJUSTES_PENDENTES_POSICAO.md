# Equalização com a Lambda e com as fotos do Itaú

## O que já foi ajustado

- Oito operações iguais às da Lambda, com parâmetros obrigatórios e responses correspondentes.
- STS ligado por operação; sete leituras `.read` e a reversão `.write`, como nas fotos.
- Authorizer REQUEST, fonte `authorization`, TTL 0 e role corporativa, confirmados na foto adicional.
- OPTIONS por mock e sem autenticação; CORS inclui Authorization e não depende de chave-unica do front.
- Erros 401/403 e falhas do authorizer com CORS e envelope `messages`.
- Removidas as referências antigas ao RDS; chave-unica é gerada por JWT HS256 na Lambda.
- Integração com o alias da esteira, em vez de `$LATEST`.
- Gerador de contrato independente para a infraestrutura do Itaú, sem criar outro API Gateway.

## Pendências que precisam de evidência do banco

1. **`permissions.json`**: a tfvars de dev aponta `PERMISSIONS_SOURCE=local`,
   `PERMISSIONS_FULL_PATH=/opt/permissions.json` e a layer
   `valida-token-permissions-posicao-custodia-numerario-v1-interno`.
   Falta o conteúdo e a origem dessa layer. Conferir as oito combinações de método/rota:
   GETs com `numerario-posicao-transportadores.read`, POST de reversão com `.write`.
   Declarar esses nomes no OpenAPI não faz o authorizer verificá-los.
2. **URI completa do authorizer**: a foto adicional corta o fim de `authorizerUri`.
   O nome usado aqui vem da tfvars de dev (`valida-token-posicao-custodia-numerario-v1-interno`).
   Conferir se a URI real usa esse nome sem alias ou aponta para versão/alias.
3. **Workflow que importa o OpenAPI** (`.github/`): falta saber quando monta o bundle,
   substitui os placeholders `iupipes_*` e cria o deployment. O gerador local produz um
   contrato por ambiente; a esteira precisa selecionar o correspondente. Não promover
   o artefato de dev sem regenerá-lo para hom/prod.
4. **VPCE e domínio/mapping reais**: a foto usa `${iupipes_deploy_aws_env_vpcEndpointId}`,
   mas não mostra o valor. O `servers` anuncia `/posicao-transportadores-bff/v1`, enquanto
   `api_gateway_api_mapping` tem padrão vazio. Confirmar a URL efetiva com o módulo/deploy.
   O VPC ID e os subnet IDs fotografados não são o ID do endpoint `execute-api`.
5. **Inventários hom/prod**: as fotos ainda mostram o exemplo inicial de Parameter Store,
   sem as variáveis de rede/API/authorizer de dev. Preencher os inventários conforme os
   módulos existentes antes do primeiro plan nesses ambientes; não reaproveitar IDs de dev.
6. **Role do authorizer**: `custom-gateway-invoke-authorizer-role` precisa confiar em
   `apigateway.amazonaws.com` e permitir `lambda:InvokeFunction` no authorizer correto.
   O campo `authorizerCredentials` não cria essas permissões.
7. **Front e TAAC**: origem CORS real, URL final do BFF, client STS com `.read` e client
   autorizado para `.write` quando forem testar reversão. O TAAC da Lambda usa a URL
   resultante em `TAAC_BASE_URL`; não pressupor stage `v1`.

## Onde encontrar o permissions.json

O usuário não encontrou esse arquivo no repositório. Isso é compatível com a
configuração fotografada: `local` significa o sistema de arquivos da Lambda, e
`/opt` é onde a AWS extrai as layers. A hipótese é que o módulo ou a esteira empacote
o JSON; as fotos não mostram quem o gera, e a AWS não cria as regras de negócio automaticamente.

Na conta dev, região `sa-east-1`, abrir a função
`valida-token-posicao-custodia-numerario-v1-interno` no console Lambda e conferir
as **Layers** associadas e suas versões. Procurar
`valida-token-permissions-posicao-custodia-numerario-v1-interno`.
É a layer do authorizer, não a layer de certificados do BFF.

Com o ARN da versão associada à função, a CLI pode retornar a URL temporária do ZIP:

```sh
aws lambda get-layer-version-by-arn --region sa-east-1 --arn "ARN-DA-VERSAO-DA-LAYER" --query Content.Location --output text
```

Baixar esse ZIP e procurar `permissions.json` na raiz. Não é necessário alterar a
função para inspecionar a layer. Se não existir função/layer implantada, conferir no
repositório interno do módulo `itau-dy9-modules-lambda-authorizer`, versão `v3.3.0`,
ou na cópia baixada em `.terraform/modules/`, como ele publica a layer de permissões.
Conferir também o job do workflow que importa o OpenAPI: ele pode gerar o JSON antes
de publicar a layer. Ainda não está confirmado se as regras vêm do OpenAPI ou de outro arquivo.

Fontes AWS: [conteúdo de layers em /opt](https://docs.aws.amazon.com/lambda/latest/dg/packaging-layers.html)
e [consulta/download da versão da layer](https://docs.aws.amazon.com/cli/latest/reference/lambda/get-layer-version-by-arn.html).

## Infraestrutura do Itaú a preservar

As fotos mostram módulos privados, diferentes dos recursos AWS diretos deste repo:

| Módulo | Versão fotografada |
|---|---|
| `itau-dy9-modules-custom-domain-name` | `v1.2.2` |
| `itau-dy9-modules-rest-api` | `v1.10.2` |
| `itau-dy9-modules-lambda-authorizer` | `v3.3.0` |
| `itau-ey4-modulo-iamsr` (TAAC) | `v2.2.1` |

Preservar `infra/main.tf`, `data.tf`, `iamsr.tf`, `variables.tf`, `versions.tf`,
`.github/`, `.stk/`, `apm.yml` e `.iupipes.yml` do banco. A foto do `.iupipes.yml`
usa Terraform 1.5.7. O Terraform de referência local exige >=1.9 e provider AWS 6;
copiá-lo por cima do banco mudaria versões e endereços do state.
Não há evidência suficiente para migrar esse state ou alterar módulos privados.

O módulo de API usa stage `dev`/`hom`/`prod`. A versão `/v1` na URL do serviço
é uma questão do mapping, não do nome do stage. A Lambda já aceita as rotas sem
prefixo e, por padrão, também remove `/v1`.

## Validação ainda necessária no ambiente

- Sem token e com token inválido: negar acesso, sem executar o BFF.
- Token com `.read`: consultar as sete rotas de leitura.
- Token somente `.read`: negar o POST de reversão.
- Token com `.write`: validar a autorização do POST com massa controlada.
- OPTIONS sem token: responder 200 com origem, métodos e headers corretos.
- Policy privada: negar acesso fora dos VPCEs autorizados.
- Lambda: alias publicado existe e as duas roles de invocação têm as permissões esperadas.

Os testes locais usam mocks e não substituem essas verificações. Nenhum deploy foi executado.
