<?php
/**
 * Plugin Name: Moinho Novo Oxygen License
 * Description: Auto-activate Oxygen license from environment variable.
 */

declare(strict_types=1);

function moinho_novo_get_oxygen_license_key(): ?string
{
    $key = getenv('OXYGEN_LICENSE_KEY');
    if (!is_string($key)) {
        return null;
    }

    $key = trim($key);
    return $key !== '' ? $key : null;
}

function moinho_novo_ensure_oxygen_active(): void
{
    if (!defined('WP_PLUGIN_DIR')) {
        return;
    }

    $plugin_file = 'oxygen/functions.php';
    $plugin_path = WP_PLUGIN_DIR . '/oxygen/functions.php';

    if (!file_exists($plugin_path)) {
        return;
    }

    if (!function_exists('is_plugin_active')) {
        require_once ABSPATH . 'wp-admin/includes/plugin.php';
    }

    if (!is_plugin_active($plugin_file)) {
        activate_plugin($plugin_file, '', false, true);
    }
}
add_action('init', 'moinho_novo_ensure_oxygen_active', 5);

function moinho_novo_activate_oxygen_license(): void
{
    if (!function_exists('is_blog_installed') || !is_blog_installed()) {
        return;
    }

    $license = moinho_novo_get_oxygen_license_key();
    if (!$license) {
        return;
    }

    if (!function_exists('is_plugin_active')) {
        require_once ABSPATH . 'wp-admin/includes/plugin.php';
    }

    if (!is_plugin_active('oxygen/functions.php')) {
        return;
    }

    $current_key = trim((string) get_option('oxygen_license_key', ''));
    $current_status = (string) get_option('oxygen_license_status', '');

    if ($current_key === $license && $current_status === 'valid') {
        return;
    }

    $last_attempt = (int) get_option('oxygen_license_last_attempt', 0);
    if (time() - $last_attempt < 3600) {
        return;
    }
    update_option('oxygen_license_last_attempt', time());

    update_option('oxygen_license_key', $license);

    $api_params = [
        'edd_action' => 'activate_license',
        'license' => $license,
        'item_name' => 'Oxygen',
        'url' => home_url(),
    ];

    $response = wp_remote_get(
        add_query_arg($api_params, 'https://oxygenbuilder.com'),
        [
            'timeout' => 15,
            'sslverify' => false,
        ]
    );

    if (is_wp_error($response)) {
        update_option('oxygen_license_status', 'error');
        update_option('oxygen_license_error', $response->get_error_message());
        return;
    }

    $license_data = json_decode(wp_remote_retrieve_body($response));
    if (isset($license_data->license)) {
        update_option('oxygen_license_status', $license_data->license);
    }

    if (isset($license_data->site_hash) && isset($license_data->license) && $license_data->license === 'valid') {
        update_option('oxygen_license_site_hash', $license_data->site_hash);
    }

    if (function_exists('oxygen_vsb_check_is_agency_bundle')) {
        oxygen_vsb_check_is_agency_bundle();
    }
}
add_action('init', 'moinho_novo_activate_oxygen_license', 20);
