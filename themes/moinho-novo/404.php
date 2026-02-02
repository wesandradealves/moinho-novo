<?php
get_header();
?>

<section class="error-404">
    <h1><?php esc_html_e('Page not found', 'moinho-novo'); ?></h1>
    <p><?php esc_html_e('It looks like nothing was found at this location.', 'moinho-novo'); ?></p>
    <?php get_search_form(); ?>
</section>

<?php
get_footer();
