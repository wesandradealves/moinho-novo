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
        'redis-cache/redis-cache.php',
    ];

    $wp_optimize = getenv('WP_OPTIMIZE_PLUGIN_FILE');
    if (!is_string($wp_optimize) || trim($wp_optimize) === '') {
        $wp_optimize = 'wp-optimize/wp-optimize.php';
    }
    $required[] = $wp_optimize;

    $defender = getenv('DEFENDER_PLUGIN_FILE');
    if (!is_string($defender) || trim($defender) === '') {
        $defender = 'defender-security/wp-defender.php';
    }
    $required[] = $defender;

    if (!function_exists('is_plugin_active')) {
        require_once ABSPATH . 'wp-admin/includes/plugin.php';
    }

    foreach ($required as $plugin_file) {
        $plugin_path = WP_PLUGIN_DIR . '/' . $plugin_file;
        if (!file_exists($plugin_path)) {
            continue;
        }

        if (strpos($plugin_file, 'all-in-one-wp-migration') !== false) {
            $plugin_dir = dirname($plugin_path);
            $vendor_file = $plugin_dir . '/lib/vendor/bandar/bandar/lib/Bandar.php';
            if (!file_exists($vendor_file)) {
                continue;
            }
        }

        if (!is_plugin_active($plugin_file)) {
            activate_plugin($plugin_file, '', false, true);
        }
    }
}
add_action('init', 'moinho_novo_activate_required_plugins', 5);

function moinho_novo_enable_redis_object_cache(): void
{
    if (!defined('WP_CONTENT_DIR') || !defined('WP_PLUGIN_DIR')) {
        return;
    }

    $plugin_file = WP_PLUGIN_DIR . '/redis-cache/redis-cache.php';
    if (!file_exists($plugin_file)) {
        return;
    }

    $dropin = WP_CONTENT_DIR . '/object-cache.php';
    $source = WP_PLUGIN_DIR . '/redis-cache/includes/object-cache.php';

    if (!file_exists($dropin) && file_exists($source)) {
        @copy($source, $dropin);
    }
}
add_action('init', 'moinho_novo_enable_redis_object_cache', 15);
