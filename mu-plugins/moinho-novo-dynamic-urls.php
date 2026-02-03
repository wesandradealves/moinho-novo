<?php
/**
 * Plugin Name: Moinho Novo Dynamic URLs
 * Description: Ajusta URLs dinamicamente por host (localhost/ngrok) para evitar quebra de assets.
 */

function mn_current_host(): string {
    if (PHP_SAPI === "cli" || defined("WP_CLI")) {
        return "";
    }

    $host = $_SERVER["HTTP_X_FORWARDED_HOST"] ?? $_SERVER["HTTP_HOST"] ?? "";
    if (!$host) {
        return "";
    }

    $parts = explode(",", $host);
    $host = trim($parts[0]);

    return $host;
}

function mn_current_scheme(): string {
    $proto = $_SERVER["HTTP_X_FORWARDED_PROTO"] ?? "";
    if ($proto && stripos($proto, "https") !== false) {
        return "https";
    }

    if (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") {
        return "https";
    }

    if (!empty($_SERVER["SERVER_PORT"]) && (int) $_SERVER["SERVER_PORT"] === 443) {
        return "https";
    }

    return "http";
}

function mn_current_origin(): string {
    $host = mn_current_host();
    if (!$host) {
        return "";
    }

    return mn_current_scheme() . "://" . $host;
}

function mn_replace_origin($value): string {
    if (!is_string($value) || $value === "") {
        return $value;
    }

    $origin = mn_current_origin();
    if (!$origin) {
        return $value;
    }

    return preg_replace("#^(https?:)?//[^/]+#", $origin, $value);
}

add_filter("option_home", function ($value) {
    $origin = mn_current_origin();
    return $origin ?: $value;
}, 1);

add_filter("option_siteurl", function ($value) {
    $origin = mn_current_origin();
    return $origin ?: $value;
}, 1);

add_filter("home_url", function ($url) {
    return mn_replace_origin($url);
}, 1);

add_filter("site_url", function ($url) {
    return mn_replace_origin($url);
}, 1);

add_filter("content_url", function ($url) {
    return mn_replace_origin($url);
}, 1);

add_filter("plugins_url", function ($url) {
    return mn_replace_origin($url);
}, 1);

add_filter("includes_url", function ($url) {
    return mn_replace_origin($url);
}, 1);

add_filter("option_oxygen_vsb_universal_css_url", function ($value) {
    return mn_replace_origin($value);
}, 1);

add_filter("option_oxygen_vsb_css_files_state", function ($value) {
    if (!is_array($value)) {
        return $value;
    }

    foreach ($value as $key => $entry) {
        if (is_array($entry) && isset($entry["url"])) {
            $value[$key]["url"] = mn_replace_origin($entry["url"]);
        }
    }

    return $value;
}, 1);

add_filter("option_wpo_cache_config", function ($value) {
    if (!is_array($value)) {
        return $value;
    }

    $origin = mn_current_origin();
    if ($origin) {
        $value["site_url"] = rtrim($origin, "/") . "/";
    }

    return $value;
}, 1);

add_action("init", function () {
    $origin = mn_current_origin();
    if (!$origin) {
        return;
    }

    if (!function_exists("get_option")) {
        return;
    }

    $config = get_option("wpo_cache_config");
    if (!is_array($config)) {
        return;
    }

    $host = parse_url($origin, PHP_URL_HOST);
    $port = parse_url($origin, PHP_URL_PORT);
    if (!$host) {
        return;
    }

    $suffix = $host . ($port ? "-port" . $port : "");
    $config_dir = WP_CONTENT_DIR . "/wpo-cache/config";
    if (!is_dir($config_dir)) {
        return;
    }

    $target = $config_dir . "/config-" . $suffix . ".php";
    if (file_exists($target)) {
        return;
    }

    $config["site_url"] = rtrim($origin, "/") . "/";
    $json = json_encode($config);
    $content = "<?php\nif (!defined(\"ABSPATH\")) die(\"No direct access allowed\");\n\n" .
        "\$GLOBALS[\"wpo_cache_config\"] = json_decode(" . var_export($json, true) . ", true);\n";
    file_put_contents($target, $content);
});
