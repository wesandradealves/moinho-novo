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
require "/var/www/html/wp-load.php";

$url = getenv("NGROK_PUBLIC_URL");
if (! $url) { exit(1); }

update_option("home", $url);
update_option("siteurl", $url);

$host = parse_url($url, PHP_URL_HOST);
$port = parse_url($url, PHP_URL_PORT);
$origin = $host ? ($host . ($port ? ":" . $port : "")) : "";
$protocol_relative = $origin ? ("//" . $origin) : "";

$replace_origin = function ($value) use ($protocol_relative) {
    if (!is_string($value) || $value === "" || $protocol_relative === "") {
        return $value;
    }
    return preg_replace("#^(https?:)?//[^/]+#", $protocol_relative, $value);
};

$universal = get_option("oxygen_vsb_universal_css_url");
$universal_new = $replace_origin($universal);
if ($universal_new !== $universal) {
    update_option("oxygen_vsb_universal_css_url", $universal_new, false);
}

$state = get_option("oxygen_vsb_css_files_state");
if (is_array($state)) {
    foreach ($state as $key => $entry) {
        if (is_array($entry) && isset($entry["url"])) {
            $state[$key]["url"] = $replace_origin($entry["url"]);
        }
    }
    update_option("oxygen_vsb_css_files_state", $state, false);
}

$wpo = get_option("wpo_cache_config");
if (is_array($wpo)) {
    $wpo["site_url"] = rtrim($url, "/") . "/";
    update_option("wpo_cache_config", $wpo, false);

    if ($origin !== "") {
        $config_dir = WP_CONTENT_DIR . "/wpo-cache/config";
        if (is_dir($config_dir)) {
            $target = $config_dir . "/config-" . $origin . ".php";
            $json = json_encode($wpo);
            $content = "<?php\nif (!defined(\"ABSPATH\")) die(\"No direct access allowed\");\n\n" .
                "\$GLOBALS[\"wpo_cache_config\"] = json_decode(" . var_export($json, true) . ", true);\n";
            file_put_contents($target, $content);
        }
    }
}

if (function_exists("flush_rewrite_rules")) {
    flush_rewrite_rules(true);
}

$htaccess = ABSPATH . ".htaccess";
if (!file_exists($htaccess)) {
    $rules = "# BEGIN WordPress\n<IfModule mod_rewrite.c>\nRewriteEngine On\nRewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]\nRewriteBase /\nRewriteRule ^index\\.php$ - [L]\nRewriteCond %{REQUEST_FILENAME} !-f\nRewriteCond %{REQUEST_FILENAME} !-d\nRewriteRule . /index.php [L]\n</IfModule>\n# END WordPress\n";
    file_put_contents($htaccess, $rules);
}
'
