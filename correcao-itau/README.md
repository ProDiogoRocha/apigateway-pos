# Recuperação do Terraform do API Gateway do Itaú

Estes dois arquivos recuperam os blocos funcionais do template mostrado nas fotos
`WhatsApp Image 2026-10-29 at 02.04.53.jpeg` a `02.09.38.jpeg`.
As fotos de main.tf/variables.tf mostram a revisão `0b0a49f`.
Comentários, descrições e formatação foram simplificados; `map` foi escrito na
forma explícita equivalente `map(any)`. Nomes de módulos, argumentos, versões,
validações e defaults foram preservados. O trecho domínio/mapping de variables.tf
foi conferido também na foto 131 da sessão anterior.

## Copiar no repositório do banco

| Arquivo desta pasta | Destino no Itaú | Ação |
|---|---|---|
| `infra/main.tf` | `infra/main.tf` | Substituir o arquivo de referência local pelo template corporativo recuperado |
| `infra/variables.tf` | `infra/variables.tf` | Substituir inteiro, recuperando todas as entradas corporativas |

O main.tf recuperado usa `module.custom_domain_name`, `module.api_gateway` e
`module.lambda_authorizer`, com as versões vistas nas fotos. Ele não usa
`templatefile("../dist/openapi.json", ...)`.

Os dois arquivos eliminam as referências causadoras dos três erros fotografados:
`api_gateway_domain_name` e `environment` voltam a estar declaradas, e o main.tf
passa a usar os módulos corporativos sem depender do bundle local no Terraform.

## Preservar no banco

- `infra/data.tf`: as fotos mostram o data source `aws_acm_certificate.certificate`
  usando `var.api_gateway_domain_name` e `aws_caller_identity.current`.
- `infra/iamsr.tf` e suas pastas de templates: continuam com a role/policy do TAAC,
  `template_dir` e `var.environment`. Os JSONs de policy/trust não foram mostrados
  e não foram inventados nesta correção.
- `infra/versions.tf`, lockfile, configuração de providers/backend, `.iupipes.yml`
  e `.github/`: manter o conjunto compatível com os módulos e com a esteira do banco.
- `infra/inventories/dev/terraform.tfvars`: preservar os dados reais fotografados.

O inventário de dev das fotos já preenche `environment`, rede, nome da API,
domínio e dados do authorizer. O ambiente continua vindo de `environment`, não
mais de `stage_name` do Terraform de referência local.

Os inventários hom/prod fotografados ainda são exemplos de Parameter Store e usam
`env`. Eles precisam dos dados de API/rede/authorizer e de `environment` antes da
promoção. Não usar os IDs de rede de dev nesses ambientes.

## Conferir outputs.tf

As fotos fornecidas não mostram um outputs.tf corporativo. O arquivo desta
referência local exporta estas duas saídas:

```hcl
output "rest_api_id" {
  value = aws_api_gateway_rest_api.bff.id
}

output "invoke_url" {
  value = aws_api_gateway_stage.bff.invoke_url
}
```

Se o outputs.tf do banco foi criado pela cópia desse arquivo, remover essas duas
saídas: os recursos diretos não existem no main.tf corporativo. Se houver saídas
corporativas anteriores, preservá-las ou recuperá-las do histórico. Não adicionar
outputs de módulos privados sem conferir os nomes que eles realmente exportam.
Conferir também qualquer outro arquivo .tf copiado que referencie esses recursos.

## Validação

A sintaxe HCL e as referências às variáveis do main.tf foram conferidas localmente.
A validação completa depende de executar terraform init/validate no ambiente com
acesso aos módulos privados, providers e templates IAM do banco.

Depois da substituição, executar o validate e o plan da esteira. Esta recuperação
mantém os endereços dos módulos das fotos e não exige migração de state nem apply
manual. Ela não prova que os arquivos atuais da branch ou o state coincidem com
as fotos; conferir o plan antes de aplicar.

A importação do OpenAPI continua na etapa corporativa própria. Esta correção não
adiciona uma importação alternativa por Terraform. Falta conferir o workflow para
fechar a aplicação do contrato atualizado e a geração da layer de permissões.
