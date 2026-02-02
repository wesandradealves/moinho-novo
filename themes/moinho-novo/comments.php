<?php
if (post_password_required()) {
    return;
}
?>

<section id="comments" class="comments-area">
    <?php if (have_comments()) : ?>
        <h2 class="comments-title">
            <?php
            printf(
                /* translators: %s: number of comments */
                esc_html(_nx('One comment', '%1$s comments', get_comments_number(), 'comments title', 'moinho-novo')),
                number_format_i18n(get_comments_number())
            );
            ?>
        </h2>

        <ol class="comment-list">
            <?php
            wp_list_comments([
                'style'      => 'ol',
                'short_ping' => true,
                'avatar_size'=> 48,
            ]);
            ?>
        </ol>

        <?php the_comments_pagination(); ?>
    <?php endif; ?>

    <?php if (! comments_open() && get_comments_number()) : ?>
        <p class="no-comments"><?php esc_html_e('Comments are closed.', 'moinho-novo'); ?></p>
    <?php endif; ?>

    <?php comment_form(); ?>
</section>
