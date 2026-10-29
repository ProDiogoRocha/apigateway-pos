# Arquivos desta equalização do API Gateway

Base: fotos 122–170 da sessão "JWT e iupipes.yaml no Itaú", foto adicional do
`APIGatewaySTSAuthorizer.yaml` e código atual da Lambda.

## O que copiar ao Itaú

**Contrato:** gerar com `npm run bundle:itau` usando ambiente, origem do front, VPCEs
e URL reais (ver README). O arquivo resultante fica em
`dist/itau/<ambiente>/itau-ln-infra-bff-posicao-apigateway.yaml`.
Copiar o conteúdo para o arquivo que o workflow do banco importa. O artefato contém
todos os componentes, STS, integração pelo alias e policy privada, sem `$ref` ou placeholders.
Cada ambiente precisa do próprio artefato; conferir a seleção no workflow antes da promoção.

**Lambda/TAAC:** em `Lambda.Itau`, copiar as alterações adicionais de
`tests/dev/PosicaoApiTests.cs`, `tests/testspec-dev.yml`, `tests/testspec-hom.yml`
e `CONFIGURACAO.md`. Foram acrescentados dois cenários de rejeição pelo STS e
corrigida a orientação sobre stage/URL. A lista geral da Lambda continua no arquivo
`ARQUIVOS_MODIFICADOS.md` desse projeto.

## Fontes alteradas neste repositório

| Arquivo | Alteração |
|---|---|
| `itau-ln-infra-bff-posicao-apigateway.yaml` | STS por operação, read/write, OPTIONS público, erros 401/403, validador de presença dos parâmetros |
| `securitySchemes/APIGatewaySTSAuthorizer.yaml` | Novo: REQUEST, fonte authorization, TTL 0, URI e role preenchidas pelo gerador/Terraform |
| `extensions/cors-preflight.yaml` | Authorization liberado; chave-unica não é enviada pelo front |
| `extensions/gateway-responses.yaml` | Erros STS e validação com CORS e envelope messages |
| `parameters/headers.yaml`, `parameters/query.yaml` | Headers e parâmetros correspondentes à Lambda; descrição do JWT sem RDS |
| `responses/erros.yaml` | 401/403 e correção das descrições |
| `redocly.yaml` | Validação de segurança religada |
| `scripts/render-itau.mjs`, `package.json` | Gerador de OpenAPI por ambiente para os módulos do banco |
| `tests/rotas.test.mjs`, `tests/render-itau.test.mjs` | Contrato, segurança, contas, aliases, roles, CORS e policy privada |
| `infra/main.tf`, `variables.tf`, `outputs.tf`, `tests/apigateway.tftest.hcl` | Referência local: alias do ambiente, authorizer existente e role corporativa; testes simulados |
| `README.md`, `AJUSTES_PENDENTES_POSICAO.md`, `ARQUIVOS_MODIFICADOS.md` | Procedimento de cópia, evidências e pendências |

## Preservar no banco

Preservar os módulos Terraform existentes, os inventários de rede, `.github/`,
`.stk/`, `apm.yml` e `.iupipes.yml`. Não copiar `infra/` local por cima do banco:
versões e endereços de state são diferentes. Os inventários hom/prod fotografados
estão incompletos e precisam dos dados reais antes do plan.

Ainda faltam: `permissions.json` e a origem da layer, fim da URI do authorizer,
workflow de importação OpenAPI, VPCEs, domínio/mapping e origem CORS reais.
As permissões efetivas e o acesso privado precisam ser testados no ambiente Itaú.


## Validação local desta rodada

- OpenAPI fonte e artefato Itaú de exemplo: lint aprovado.
- Contrato e gerador: 21 testes aprovados.
- Terraform de referência: validate e 9 testes com provider simulado aprovados.
- Lambda: 106 testes aprovados; cobertura de linhas 100% (587/587) e branches 98,4% (188/191).
- TAAC: build sem avisos/erros; não executado contra o Itaú.
- Nenhum deploy executado nesta rodada.


## Collection de requests para desenvolvimento

Nova pasta `curl/dev/`: oito cURLs dos endpoints, obtenção de token STS, preflight CORS,
variáveis de exemplo, collection e environment do Postman e instruções de uso.
O `.gitignore` exclui os arquivos de configuração local com credenciais.
São ferramentas de teste manual; não precisam ser copiadas para a infraestrutura do banco.
