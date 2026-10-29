#!/usr/bin/env bash
set -euo pipefail

# A resposta JSON contém access_token. Use esse valor em TOKEN_STS, sem Bearer.
curl --silent --show-error --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  --request POST \
  --url "${STS_URL:-https://des-sts-int.mbi.cloud.ihf/api/oauth/token}" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --header "Accept: application/json" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=${STS_CLIENT_ID:?Defina STS_CLIENT_ID}" \
  --data-urlencode "client_secret=${STS_CLIENT_SECRET:?Defina STS_CLIENT_SECRET}"
