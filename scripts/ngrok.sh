#!/usr/bin/env bash
set -euo pipefail

if docker compose version >/dev/null 2>&1; then
    DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    DC=(docker-compose)
else
    echo "Docker Compose not found."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

if [ -f "${PROJECT_DIR}/.env" ]; then
    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
            ''|\#*) continue ;;
        esac
        line="${line#export }"
        if [[ "${line}" == *"="* ]]; then
            key="${line%%=*}"
            val="${line#*=}"
            val="${val%\"}"
            val="${val#\"}"
            current="${!key:-}"
            if [ -z "${current}" ]; then
                export "${key}=${val}"
            fi
        fi
    done < "${PROJECT_DIR}/.env"
fi

if [ -z "${NGROK_AUTHTOKEN:-}" ]; then
    echo "NGROK_AUTHTOKEN nao encontrado. Defina no .env."
    exit 1
fi

"${DC[@]}" up -d wordpress db redis
"${DC[@]}" --profile ngrok up -d ngrok

get_ngrok_url() {
    "${DC[@]}" exec -T wordpress php -r ' 
$body = @file_get_contents("http://ngrok:4040/api/tunnels");
if ($body === false) { exit(0); }
$data = json_decode($body, true);
if (!is_array($data) || empty($data["tunnels"])) { exit(0); }
foreach ($data["tunnels"] as $tunnel) {
    if (isset($tunnel["public_url"]) && str_starts_with($tunnel["public_url"], "https://")) {
        echo $tunnel["public_url"]; 
        break;
    }
}
'
}

url=""
for _ in $(seq 1 30); do
    url="$(get_ngrok_url || true)"
    if [[ "${url}" == https://* ]]; then
        break
    fi
    sleep 2
done

if [[ "${url}" != https://* ]]; then
    echo "Nao foi possivel obter a URL do ngrok."
    exit 1
fi

echo "NGROK URL: ${url}"

"${PROJECT_DIR}/scripts/set-site-url.sh" "${url}"
