<?php
/**
 * Plugin Name: Moinho Novo Login Redirect
 * Description: Redireciona wp-login.php para /login/ e ajusta links de login.
 */

add_filter('login_url', function ($login_url, $redirect, $force_reauth) {
    $url = home_url('/login/');

    if (!empty($redirect)) {
        $url = add_query_arg('redirect_to', wp_unslash($redirect), $url);
    }
    if ($force_reauth) {
        $url = add_query_arg('reauth', '1', $url);
    }

    return $url;
}, 10, 3);

add_action('init', function () {
    if (defined('DOING_AJAX') && DOING_AJAX) {
        return;
    }

    $request_uri = $_SERVER['REQUEST_URI'] ?? '';
    $path = $request_uri ? parse_url($request_uri, PHP_URL_PATH) : '';
    if (! $path || basename($path) !== 'wp-login.php') {
        return;
    }

    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if (!in_array($method, ['GET', 'HEAD'], true)) {
        return;
    }

    $action = $_REQUEST['action'] ?? '';
    if ($action && $action !== 'login') {
        return;
    }

    $target = home_url('/login/');
    if (!empty($_REQUEST['redirect_to'])) {
        $target = add_query_arg('redirect_to', wp_unslash($_REQUEST['redirect_to']), $target);
    }
    if (!empty($_REQUEST['reauth'])) {
        $target = add_query_arg('reauth', '1', $target);
    }

    wp_safe_redirect($target);
    exit;
});

add_filter('login_redirect', function ($redirect_to, $requested_redirect_to, $user) {
    if (! $user || is_wp_error($user)) {
        return $redirect_to;
    }

    return admin_url();
}, 10, 3);
