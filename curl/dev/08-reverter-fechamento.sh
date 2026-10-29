#!/usr/bin/env bash
set -euo pipefail

# Reverter fechamento.
# Altera a posição escolhida em dev. Execute com massa de teste.
# codigoTipoPosicao é uma string JSON, conforme o contrato.
body=$(printf '{"codigoTipoPosicao":"%s"}' "${CODIGO_TIPO_POSICAO:?Defina CODIGO_TIPO_POSICAO}")
: "${BASE_URL:?Defina BASE_URL com a URL real do BFF em dev}"

curl --silent --show-error --include --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  --request POST \
  --url "${BASE_URL%/}/posicao-transportadores/${INDICE_CONTROLE_POSICAO:?Defina INDICE_CONTROLE_POSICAO com o indice retornado nos cards}/reverter" \
  --header "authorization: Bearer ${TOKEN_STS:?Defina TOKEN_STS com o access_token do STS}" \
  --header "x-itau-apikey: ${API_KEY:?Defina API_KEY}" \
  --header "x-itau-correlationID: ${CORRELATION_ID:-curl-dev-$(date +%s)-$$}" \
  --header "Accept: application/json" \
  --url-query "centralizador=${CENTRALIZADOR:?Defina CENTRALIZADOR}" \
  --url-query "polo=${POLO:?Defina POLO}" \
  --url-query "transportadora=${TRANSPORTADORA:?Defina TRANSPORTADORA}" \
  --header "Content-Type: application/json" \
  --data-raw "$body"
