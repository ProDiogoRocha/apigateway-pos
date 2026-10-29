# Requests do BFF de posição em desenvolvimento

Uma requisição por arquivo cURL, cobrindo as oito operações do API Gateway.
Há também obtenção de token STS e preflight CORS. Os comandos são para **Bash**
(Git Bash, WSL ou Linux), com cURL **7.87 ou superior**; a reversão usa `--url-query`.
No Postman, importe os dois arquivos JSON desta pasta.

## Executar os cURLs

Abra um terminal nesta pasta:

```bash
cp variables.env.example variables.local.env
# Edite variables.local.env e preencha a URL e as credenciais/variáveis necessárias.
source ./variables.local.env
```

`variables.local.env` é ignorado pelo Git. O exemplo não contém token nem credenciais.

- `BASE_URL`: URL real do **Gateway do BFF** em dev, incluindo o mapping configurado.
  Ex.: URL execute-api com stage `/dev`, ou domínio corporativo com seu mapping real.
  Não usar a URL do ECS nem acrescentar `/v1` sem conferir o mapping.
- `API_KEY`: valor de `x-itau-apikey` (o exemplo `1` vem do TAAC; ajuste se necessário).
- `CENTRALIZADOR=7619`, `POLO=001` e `TRANSPORTADORA=56`: exemplos do TAAC;
  confirme a massa disponível. `TRANSPORTADORA` é o fornecedor, não a base.
- `DATA_MOVIMENTO`: o exemplo usa a data atual de São Paulo; ajuste para uma data com posições.

Obtenha o token STS com um client autorizado a chamar o BFF:

```bash
bash ./00-obter-token-sts.sh
# Copie somente o access_token retornado, sem o prefixo Bearer:
export TOKEN_STS='PREENCHER_ACCESS_TOKEN'
```

Se já tiver um token STS, basta definir `TOKEN_STS`; não precisa executar o arquivo 00.
As consultas usam `.read`; a reversão exige `.write`, conforme as regras do authorizer.
O JWT `chave-unica` é gerado pela Lambda e não deve ser enviado nesses requests.

## Ordem sugerida e endpoints

Execute cada request individualmente:

| Arquivo | Método e rota |
|---|---|
| `01-consultar-centralizador.sh` | `GET /centralizadores/{numeroCentralizador}` |
| `02-consultar-fornecedor.sh` | `GET /centralizadores/{numeroCentralizador}/fornecedores/{fornecedorId}` |
| `03-consultar-fornecedor-na-base.sh` | `GET /centralizadores/{numeroCentralizador}/fornecedores/{fornecedorId}/bases/{baseId}` |
| `04-consultar-polo.sh` | `GET /centralizadores/{numeroCentralizador}/polos/{poloId}` |
| `05-consultar-cards.sh` | `GET /posicao-transportadores` |
| `06-consultar-divergencias.sh` | `GET /posicao-transportadores/{indiceControlePosicao}/justificativa-divergencias` |
| `07-consultar-termo-juridico.sh` | `GET /posicao-transportadores/{indiceControlePosicao}/justificativa-termo-juridico` |
| `08-reverter-fechamento.sh` | `POST /posicao-transportadores/{indiceControlePosicao}/reverter` |

Por exemplo:

```bash
bash ./01-consultar-centralizador.sh
bash ./02-consultar-fornecedor.sh
# Da resposta do fornecedor, selecione o codigoBaseFornecedor da massa desejada:
export BASE_ID='PREENCHER_CODIGO_BASE_FORNECEDOR'
bash ./03-consultar-fornecedor-na-base.sh
bash ./04-consultar-polo.sh
bash ./05-consultar-cards.sh
# Dos cards, selecione o indiceControlePosicao que deseja consultar:
export INDICE_CONTROLE_POSICAO='PREENCHER_INDICE_CONTROLE_POSICAO'
bash ./06-consultar-divergencias.sh
bash ./07-consultar-termo-juridico.sh
```

A **reversão altera a posição selecionada em dev**. Execute com massa de teste e
com `CODIGO_TIPO_POSICAO` correspondente à posição (`F` é o exemplo do contrato):

```bash
bash ./08-reverter-fechamento.sh
```

As quatro rotas de posição enviam `centralizador`, `polo` e `transportadora` na
query string. A consulta de cards envia também `data`. A reversão envia
`{"codigoTipoPosicao":"F"}` no body JSON. Cada chamada recebe um correlation ID;
defina `CORRELATION_ID` se quiser escolher o identificador manualmente.

Os scripts mostram o status HTTP, os headers e o body. Em HTTP 4xx/5xx, o cURL
preserva o body e retorna código de saída diferente de zero.

## Testar o preflight

```bash
export CORS_ORIGIN='https://ORIGEM-REAL-DO-FRONT'
bash ./09-preflight-cors.sh
```

Para outra rota/método, por exemplo a reversão:

```bash
CORS_METHOD=POST \
CORS_PATH="/posicao-transportadores/${INDICE_CONTROLE_POSICAO}/reverter" \
bash ./09-preflight-cors.sh
```

O OPTIONS não envia token nem API key. Confira o status 200, a origem permitida e
os headers/métodos CORS na resposta. cURL não aplica as restrições CORS do navegador.

## Importar no Postman

1. Importe `posicao-dev.postman_collection.json` e `dev.postman_environment.json`.
2. Selecione o environment **BFF Posição - DEV (preencher valores locais)**.
3. Preencha `baseUrl`, `clientId`, `clientSecret`, `dataMovimento` (`yyyy-MM-dd`) e,
   conforme a operação, `baseId`, `indiceControlePosicao` e `corsOrigin`.
4. Execute **00 - Obter token STS**. Uma resposta com `access_token` preenche `tokenSts`
   no environment automaticamente. Também pode preencher `tokenSts` manualmente.
5. Envie as consultas individualmente e selecione a massa antes de executar a reversão.

A collection usa `{{$guid}}` para criar um correlation ID por chamada.
Se exportar o environment com valores reais, use o nome
`dev.local.postman_environment.json`, ignorado pelo Git.

A API é privada: execute a partir da rede do Itaú que tenha acesso ao Gateway e ao STS.
O cURL usa as CAs confiáveis da máquina. Se precisar indicar o bundle corporativo,
configure `CURL_CA_BUNDLE` com o caminho do arquivo de certificados.
