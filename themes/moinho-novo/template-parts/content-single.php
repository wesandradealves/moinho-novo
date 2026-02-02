<?php
?>
<article id="post-<?php the_ID(); ?>" <?php post_class('entry'); ?>>
    <header class="entry-header">
        <?php the_title('<h1 class="entry-title">', '</h1>'); ?>
        <div class="entry-meta">
            <span class="posted-on"><?php echo esc_html(get_the_date()); ?></span>
            <span class="byline"><?php esc_html_e('by', 'moinho-novo'); ?> <?php the_author(); ?></span>
        </div>
    </header>

    <div class="entry-content">
        <?php
        the_content();
        wp_link_pages([
            'before' => '<div class="page-links">' . esc_html__('Pages:', 'moinho-novo'),
            'after'  => '</div>',
        ]);
        ?>
    </div>

    <footer class="entry-footer">
        <?php the_tags('<span class="tags-links">', ', ', '</span>'); ?>
    </footer>
</article>
