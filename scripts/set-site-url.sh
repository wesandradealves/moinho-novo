#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Uso: $0 <url>"
    exit 1
fi

TARGET_URL="$1"

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

OLD_URL="$("${DC[@]}" exec -T wordpress php -r "require \"/var/www/html/wp-load.php\"; echo get_option(\"home\");")"

"${DC[@]}" exec -T -e TARGET_URL="${TARGET_URL}" wordpress php -r '
require "/var/www/html/wp-load.php";

$url = getenv("TARGET_URL");
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

# Sincroniza URLs no banco (conteudo/oxygen) para evitar mixed content no ngrok.
if [ -n "${OLD_URL}" ] && [ "${OLD_URL}" != "${TARGET_URL}" ]; then
    OLD_HOST="$(php -r "echo parse_url(\"${OLD_URL}\", PHP_URL_HOST) ?: \"\";")"
    OLD_PORT="$(php -r "echo parse_url(\"${OLD_URL}\", PHP_URL_PORT) ?: \"\";")"
    if [ -n "${OLD_HOST}" ]; then
        OLD_ORIGIN="${OLD_HOST}"
        if [ -n "${OLD_PORT}" ]; then
            OLD_ORIGIN="${OLD_ORIGIN}:${OLD_PORT}"
        fi
        OLD_HTTP="http://${OLD_ORIGIN}"
        OLD_HTTPS="https://${OLD_ORIGIN}"
        NEW_HOST="$(php -r "echo parse_url(\"${TARGET_URL}\", PHP_URL_HOST) ?: \"\";")"
        NEW_PORT="$(php -r "echo parse_url(\"${TARGET_URL}\", PHP_URL_PORT) ?: \"\";")"
        NEW_ORIGIN="${NEW_HOST}"
        if [ -n "${NEW_PORT}" ]; then
            NEW_ORIGIN="${NEW_ORIGIN}:${NEW_PORT}"
        fi
        NEW_HTTP="http://${NEW_ORIGIN}"
        NEW_HTTPS="https://${NEW_ORIGIN}"

        "${DC[@]}" exec -T wordpress bash -lc '
set -e
WP=/tmp/wp-cli.phar
if ! command -v wp >/dev/null 2>&1; then
    if [ ! -f "${WP}" ]; then
        curl -fsSL -o "${WP}" https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x "${WP}"
    fi
    WP_CMD=(php "${WP}")
else
    WP_CMD=(wp)
fi
"${WP_CMD[@]}" --path=/var/www/html search-replace "'"${OLD_HTTP}"'" "'"${NEW_HTTP}"'" --skip-columns=guid --all-tables-with-prefix || true
"${WP_CMD[@]}" --path=/var/www/html search-replace "'"${OLD_HTTPS}"'" "'"${NEW_HTTPS}"'" --skip-columns=guid --all-tables-with-prefix || true
'
    fi
fi

# Normaliza URLs do Oxygen (uploads/oxygen/css) para paths relativos,
# garantindo funcionamento tanto em localhost quanto ngrok.
"${DC[@]}" exec -T wordpress bash -lc '
set -e
CSS_DIR="/var/www/html/wp-content/uploads/oxygen/css"
if [ -d "${CSS_DIR}" ]; then
    find "${CSS_DIR}" -type f -name "*.css" -print0 | xargs -0 sed -i -E \
        -e "s#https?://[^/]+/wp-content/uploads#/wp-content/uploads#g" \
        -e "s#//[^/]+/wp-content/uploads#/wp-content/uploads#g"
fi
'
