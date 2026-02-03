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

