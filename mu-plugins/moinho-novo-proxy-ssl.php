<?php
/**
 * Plugin Name: Moinho Novo Proxy SSL
 * Description: Ajusta HTTPS quando esta atras de proxy (ex.: ngrok) para evitar redirect loop.
 */

$forwarded_proto = $_SERVER["HTTP_X_FORWARDED_PROTO"] ?? "";
$forwarded_ssl = $_SERVER["HTTP_X_FORWARDED_SSL"] ?? "";
$forwarded_host = $_SERVER["HTTP_X_FORWARDED_HOST"] ?? "";
$forwarded_port = $_SERVER["HTTP_X_FORWARDED_PORT"] ?? "";

if ($forwarded_proto && stripos($forwarded_proto, "https") !== false) {
    $_SERVER["HTTPS"] = "on";
    $_SERVER["REQUEST_SCHEME"] = "https";
    $_SERVER["SERVER_PORT"] = 443;
}

if ($forwarded_ssl && strtolower($forwarded_ssl) === "on") {
    $_SERVER["HTTPS"] = "on";
    $_SERVER["REQUEST_SCHEME"] = "https";
    $_SERVER["SERVER_PORT"] = 443;
}

if ($forwarded_host) {
    $_SERVER["HTTP_HOST"] = $forwarded_host;
}

if ($forwarded_port) {
    $_SERVER["SERVER_PORT"] = $forwarded_port;
}
