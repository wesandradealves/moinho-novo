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

"${DC[@]}" exec -T -e NGROK_PUBLIC_URL="${url}" wordpress php -r ' 
$url = getenv("NGROK_PUBLIC_URL");
if (! $url) { exit(1); }

$db_host = getenv("WORDPRESS_DB_HOST") ?: "db";
$db_name = getenv("WORDPRESS_DB_NAME") ?: "wordpress";
$db_user = getenv("WORDPRESS_DB_USER") ?: "wordpress";
$db_pass = getenv("WORDPRESS_DB_PASSWORD") ?: "wordpress";
$prefix = getenv("WORDPRESS_TABLE_PREFIX") ?: "wp_";

$mysqli = @new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($mysqli->connect_errno) {
    fwrite(STDERR, "Erro ao conectar no banco: " . $mysqli->connect_error . PHP_EOL);
    exit(1);
}
$safe = $mysqli->real_escape_string($url);
$mysqli->query("UPDATE {$prefix}options SET option_value=\"{$safe}\" WHERE option_name IN (\"home\",\"siteurl\")");

// Atualiza config do WP-Optimize (evita erro de cache ao mudar o dominio).
$config_dir = "/var/www/html/wp-content/wpo-cache/config";
if (is_dir($config_dir)) {
    $host = parse_url($url, PHP_URL_HOST);
    $port = parse_url($url, PHP_URL_PORT);
    if ($host) {
        $suffix = $host . ($port ? "-port" . $port : "");
        $target = $config_dir . "/config-" . $suffix . ".php";
        $existing = glob($config_dir . "/config-*.php");
        $config = null;
        if (!empty($existing)) {
            if (!defined("ABSPATH")) {
                define("ABSPATH", "/var/www/html/");
            }
            require $existing[0];
            if (isset($GLOBALS["wpo_cache_config"]) && is_array($GLOBALS["wpo_cache_config"])) {
                $config = $GLOBALS["wpo_cache_config"];
            }
        }
        if (is_array($config)) {
            $config["site_url"] = rtrim($url, "/") . "/";
            $json = json_encode($config);
            $content = "<?php\nif (!defined(\"ABSPATH\")) die(\"No direct access allowed\");\n\n" .
                "\$GLOBALS[\"wpo_cache_config\"] = json_decode(" . var_export($json, true) . ", true);\n";
            file_put_contents($target, $content);
        }
    }
}
'

"${DC[@]}" exec -T wordpress php -r ' 
require "/var/www/html/wp-load.php";
if (function_exists("flush_rewrite_rules")) { flush_rewrite_rules(true); }
'
