<?php
?><!doctype html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<div class="site">
    <header class="site-header">
        <h1 class="site-title">
            <a href="<?php echo esc_url(home_url('/')); ?>">
                <?php bloginfo('name'); ?>
            </a>
        </h1>
        <p class="site-description"><?php bloginfo('description'); ?></p>

        <?php if (has_nav_menu('primary')) : ?>
            <nav class="site-nav" aria-label="<?php esc_attr_e('Primary', 'moinho-novo'); ?>">
                <?php
                wp_nav_menu([
                    'theme_location' => 'primary',
                    'container' => false,
                ]);
                ?>
            </nav>
        <?php endif; ?>
    </header>

    <main class="site-main">
