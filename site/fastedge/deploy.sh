#!/bin/sh
# Build the site, upload the Wasm binary, point the FastEdge app at it and
# purge the CDN cache.
#
#   GCORE_API_KEY=... sh site/fastedge/deploy.sh
#
# Needs: rustup with the wasm32-wasip1 target, curl, jq.
set -eu
: "${GCORE_API_KEY:?set GCORE_API_KEY}"
APP_ID=${FASTEDGE_APP_ID:-3923}
CDN_ID=${CDN_RESOURCE_ID:-1517230}
API=https://api.gcore.com
AUTH="Authorization: APIKey $GCORE_API_KEY"

cd "$(dirname "$0")"
RUSTC="$(rustup which rustc)" "$(rustup which cargo)" build --release
wasm=target/wasm32-wasip1/release/etc_agents_site.wasm

bin=$(curl -sf -X POST "$API/fastedge/v1/binaries/raw" -H "$AUTH" \
    -H "Content-Type: application/octet-stream" --data-binary "@$wasm" | jq -r .id)
echo "binary: $bin"

# PUT replaces the whole app config: read it, drop the read-only fields,
# set the new binary.
curl -sf "$API/fastedge/v1/apps/$APP_ID" -H "$AUTH" |
jq --argjson b "$bin" '
    del(.api_type, .networks, .plan, .plan_id, .url, .created_at, .updated_at, .id)
    | .binary = $b
    | if .secrets then .secrets |= with_entries(.value = {id: .value.id}) else . end' |
curl -sf -X PUT "$API/fastedge/v1/apps/$APP_ID" -H "$AUTH" \
    -H "Content-Type: application/json" -d @- | jq -c '{id, name, binary, status, url}'

curl -sf -o /dev/null -X POST "$API/cdn/resources/$CDN_ID/purge" -H "$AUTH" \
    -H "Content-Type: application/json" -d '{"paths": []}'
echo "CDN cache purged"
