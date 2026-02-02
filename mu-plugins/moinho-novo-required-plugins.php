<?php
/**
 * Plugin Name: Moinho Novo Required Plugins
 * Description: Auto-activate required plugins (Contact Form 7).
 */

declare(strict_types=1);

function moinho_novo_activate_required_plugins(): void
{
    if (!defined('WP_PLUGIN_DIR')) {
        return;
    }

    $required = [
        'contact-form-7/wp-contact-form-7.php',
    ];

    if (!function_exists('is_plugin_active')) {
        require_once ABSPATH . 'wp-admin/includes/plugin.php';
    }

    foreach ($required as $plugin_file) {
        $plugin_path = WP_PLUGIN_DIR . '/' . $plugin_file;
        if (!file_exists($plugin_path)) {
            continue;
        }

        if (!is_plugin_active($plugin_file)) {
            activate_plugin($plugin_file, '', false, true);
        }
    }
}
add_action('init', 'moinho_novo_activate_required_plugins', 5);
