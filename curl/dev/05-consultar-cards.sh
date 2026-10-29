#!/usr/bin/env bash
set -euo pipefail

# Consultar cards.
: "${BASE_URL:?Defina BASE_URL com a URL real do BFF em dev}"

curl --silent --show-error --include --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  --get \
  --url "${BASE_URL%/}/posicao-transportadores" \
  --header "authorization: Bearer ${TOKEN_STS:?Defina TOKEN_STS com o access_token do STS}" \
  --header "x-itau-apikey: ${API_KEY:?Defina API_KEY}" \
  --header "x-itau-correlationID: ${CORRELATION_ID:-curl-dev-$(date +%s)-$$}" \
  --header "Accept: application/json" \
  --data-urlencode "data=${DATA_MOVIMENTO:?Defina DATA_MOVIMENTO}" \
  --data-urlencode "centralizador=${CENTRALIZADOR:?Defina CENTRALIZADOR}" \
  --data-urlencode "polo=${POLO:?Defina POLO}" \
  --data-urlencode "transportadora=${TRANSPORTADORA:?Defina TRANSPORTADORA}"
