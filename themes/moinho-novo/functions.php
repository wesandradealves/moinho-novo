<?php

declare(strict_types=1);

/**
 * Theme setup.
 */
function moinho_novo_setup(): void
{
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('html5', [
        'search-form',
        'comment-form',
        'comment-list',
        'gallery',
        'caption',
        'style',
        'script',
    ]);

    register_nav_menus([
        'primary' => __('Primary Menu', 'moinho-novo'),
    ]);
}
add_action('after_setup_theme', 'moinho_novo_setup');

/**
 * Enqueue styles.
 */
function moinho_novo_assets(): void
{
    $theme_version = wp_get_theme()->get('Version');
    wp_enqueue_style('moinho-novo-style', get_stylesheet_uri(), [], $theme_version);
}
add_action('wp_enqueue_scripts', 'moinho_novo_assets');

/**
 * Register widget areas.
 */
function moinho_novo_widgets_init(): void
{
    register_sidebar([
        'name'          => __('Sidebar', 'moinho-novo'),
        'id'            => 'sidebar-1',
        'description'   => __('Main sidebar area', 'moinho-novo'),
        'before_widget' => '<section id="%1$s" class="widget %2$s">',
        'after_widget'  => '</section>',
        'before_title'  => '<h3 class="widget-title">',
        'after_title'   => '</h3>',
    ]);
}
add_action('widgets_init', 'moinho_novo_widgets_init');
