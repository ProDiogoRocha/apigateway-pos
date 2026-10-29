#!/usr/bin/env bash
set -euo pipefail

# Sem token STS. CORS_PATH e CORS_METHOD permitem verificar qualquer uma das oito rotas.
: "${BASE_URL:?Defina BASE_URL com a URL real do BFF em dev}"
curl --silent --show-error --include --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  --request OPTIONS \
  --url "${BASE_URL%/}${CORS_PATH:-/posicao-transportadores}" \
  --header "Origin: ${CORS_ORIGIN:?Defina CORS_ORIGIN com a origem do front}" \
  --header "Access-Control-Request-Method: ${CORS_METHOD:-GET}" \
  --header "Access-Control-Request-Headers: authorization,x-itau-apikey,x-itau-correlationID,content-type"
