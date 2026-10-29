# Três erros de Terraform na esteira do API Gateway

## Arquivos de correção prontos

As 14 fotos adicionais do template original foram lidas pelo caminho Windows
montado em `/mnt/c/Users/prodi/Downloads`. Elas mostram os módulos corporativos
e as declarações de `environment` e `api_gateway_domain_name`.

Os arquivos [`correcao-itau/infra/main.tf`](correcao-itau/infra/main.tf) e
[`correcao-itau/infra/variables.tf`](correcao-itau/infra/variables.tf) recuperam esse
conjunto. Copiar para os paths correspondentes no banco. Preservar data.tf,
iamsr.tf, templates IAM e inventários; conferir outputs.tf conforme o
[README da recuperação](correcao-itau/README.md).

O template original não depende de `dist/openapi.json` no main.tf. A recuperação
não passa a importar o OpenAPI por outro recurso Terraform; o workflow corporativo
de importação ainda precisa ser conferido separadamente.

## Diagnóstico a partir das fotos do log

| Erro | Arquivo | O que a configuração está usando |
|---|---|---|
| `var.api_gateway_domain_name` não declarada | `infra/data.tf:2` | Data source de certificado do domínio corporativo |
| `var.environment` não declarada | `infra/iamsr.tf:21` | Seleção de ambiente do IAM/TAAC corporativo |
| `../dist/openapi.json` não existe | `infra/main.tf:34` | Importação de OpenAPI pelo Terraform de referência local |

A terceira referência coincide com o `main.tf` local. As duas primeiras coincidem
com os arquivos corporativos fotografados, cujas variáveis não estão no
`variables.tf` de referência. A hipótese é que `main.tf`/`variables.tf` locais
substituíram os do banco, mantendo `data.tf` e `iamsr.tf` corporativos.
É preciso conferir os arquivos atuais do banco para confirmar o conjunto exato.

## Correção para a implementação corporativa

1. Conferir no histórico do repositório do banco o conjunto anterior à cópia dos
   arquivos de referência. Usar `git log --oneline -- infra/main.tf infra/variables.tf`
   e visualizar o conteúdo dos arquivos nessa revisão antes de restaurar.
2. Recuperar o `main.tf` corporativo com os blocos `module "custom_domain_name"`,
   `module "api_gateway"` e `module "lambda_authorizer"`, preservando seus nomes e
   versões. As fotos mostram respectivamente `v1.2.2`, `v1.10.2` e `v3.3.0`.
3. Recuperar o `variables.tf` correspondente, incluindo `environment`,
   `api_gateway_domain_name` e as demais entradas dos módulos. Os inventários
   corporativos devem fornecer os valores de cada ambiente.
4. Conferir `outputs.tf`, `versions.tf` e o lockfile se também foram substituídos.
   O `outputs.tf` daqui referencia recursos AWS diretos; ele não corresponde aos
   módulos corporativos. Se o arquivo foi criado somente pela cópia, remover essas
   saídas da configuração do banco; se já existia, restaurar a versão corporativa.
   Não inventar nomes de outputs dos módulos privados.
5. Preservar `data.tf`, `iamsr.tf`, templates IAM, inventários, `.iupipes.yml` e
   `.github/` corporativos. Conferir o workflow que importa o OpenAPI e como o
   contrato correto é selecionado por ambiente.
6. Executar o validate/plan com o mesmo ambiente e versões da esteira e revisar o
   resultado antes de qualquer apply. Este roteiro não pede migração de state.

Os três erros não se resolvem de forma completa apenas declarando duas variáveis
e criando um arquivo vazio em `dist/`.

## Por que o bundle falta

`dist/` é gerado por `npm run bundle` e fica no `.gitignore`. O `main.tf` de
referência usa `templatefile` e espera que o JSON exista antes da execução do
Terraform. A função não espera um arquivo que será criado posteriormente.
[Documentação HashiCorp](https://developer.hashicorp.com/terraform/language/functions/templatefile).

No fluxo corporativo, confirmar a etapa real de importação do contrato; executar
`npm run bundle` somente na máquina pessoal não disponibiliza o arquivo no runner.
O bundle local também contém placeholders próprios do Terraform de referência.
O `bundle:itau` gera o contrato para uso com a infraestrutura corporativa, conforme
o README, e precisa ser selecionado corretamente para cada ambiente no workflow.

## Evidência necessária para fechar a correção

Conteúdo atual de `infra/main.tf`, `infra/variables.tf` e `infra/outputs.tf` do
repositório do banco, além da etapa do workflow que importa o OpenAPI. O acesso ao
repositório pessoal não permite inspecionar esses arquivos atuais do Itaú.
