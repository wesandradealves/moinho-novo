<?php
?>
<article id="post-<?php the_ID(); ?>" <?php post_class('entry'); ?>>
    <header class="entry-header">
        <?php the_title('<h1 class="entry-title">', '</h1>'); ?>
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
</article>
