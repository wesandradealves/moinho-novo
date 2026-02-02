<?php
?>
<section class="no-results not-found">
    <h2><?php esc_html_e('Nothing found', 'moinho-novo'); ?></h2>

    <?php if (is_search()) : ?>
        <p><?php esc_html_e('Sorry, but nothing matched your search terms. Please try again.', 'moinho-novo'); ?></p>
        <?php get_search_form(); ?>
    <?php else : ?>
        <p><?php esc_html_e('It seems we cannot find what you are looking for.', 'moinho-novo'); ?></p>
    <?php endif; ?>
</section>
