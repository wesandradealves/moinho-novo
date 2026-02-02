<?php
/**
 * Plugin Name: Moinho Novo Oxygen Fallback
 * Description: Usa o tema quando nao ha template do Oxygen e garante jQuery no frontend.
 */

declare(strict_types=1);

function moinho_novo_oxygen_is_unused(): bool
{
    if (!class_exists('wpdb')) {
        return false;
    }

    global $wpdb;
    $has_templates = (int) $wpdb->get_var(
        "SELECT ID FROM {$wpdb->posts} WHERE post_type='ct_template' AND post_status NOT IN ('trash','auto-draft') LIMIT 1"
    );

    if ($has_templates > 0) {
        return false;
    }

    $has_custom_views = (int) $wpdb->get_var(
        "SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key='ct_builder_json' AND meta_value <> '' LIMIT 1"
    );

    return $has_custom_views === 0;
}

function moinho_novo_disable_oxygen_theme_override(): void
{
    if (defined('SHOW_CT_BUILDER') || defined('OXYGEN_IFRAME')) {
        return;
    }

    if (!moinho_novo_oxygen_is_unused()) {
        return;
    }

    remove_filter('template_directory', 'ct_disable_theme_load', 1);
    remove_filter('stylesheet_directory', 'ct_disable_theme_load', 1);
    remove_filter('stylesheet', 'ct_disable_theme_load', 1);
    remove_filter('template', 'ct_oxygen_template_name');
    remove_filter('template_include', 'ct_determine_render_template', 98);
    remove_filter('template_include', 'ct_css_output', 99);
    remove_action('wp_head', 'oxy_print_cached_css', 999999);
}
add_action('plugins_loaded', 'moinho_novo_disable_oxygen_theme_override', 100);

function moinho_novo_restore_theme_paths(): void
{
    if (defined('SHOW_CT_BUILDER') || defined('OXYGEN_IFRAME')) {
        return;
    }

    if (!moinho_novo_oxygen_is_unused()) {
        return;
    }

    $theme = wp_get_theme();
    $GLOBALS['wp_template_path'] = $theme->get_template_directory();
    $GLOBALS['wp_stylesheet_path'] = $theme->get_stylesheet_directory();
}
add_action('setup_theme', 'moinho_novo_restore_theme_paths', 20);

function moinho_novo_force_jquery(): void
{
    if (is_admin()) {
        return;
    }

    wp_enqueue_script('jquery');
}
add_action('wp_enqueue_scripts', 'moinho_novo_force_jquery', 5);

function moinho_novo_dequeue_oxygen_assets(): void
{
    if (is_admin() || defined('SHOW_CT_BUILDER') || defined('OXYGEN_IFRAME')) {
        return;
    }

    if (!moinho_novo_oxygen_is_unused()) {
        return;
    }

    wp_dequeue_style('oxygen');
    wp_dequeue_style('oxygen-universal-styles');
    wp_dequeue_style('oxygen-oo-css');
    wp_dequeue_style('oxygen-dynamic-css');
    wp_dequeue_style('ct-dynamic-css');

    wp_dequeue_script('oxygen-js');
    wp_dequeue_script('oxygen-head-js');
    wp_dequeue_script('ct-scripts');
}
add_action('wp_print_styles', 'moinho_novo_dequeue_oxygen_assets', 100);
add_action('wp_print_scripts', 'moinho_novo_dequeue_oxygen_assets', 100);
