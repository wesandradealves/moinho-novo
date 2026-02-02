<?php
?>
<article id="post-<?php the_ID(); ?>" <?php post_class('entry'); ?>>
    <header class="entry-header">
        <?php the_title(sprintf('<h2 class="entry-title"><a href="%s">', esc_url(get_permalink())), '</a></h2>'); ?>
        <div class="entry-meta">
            <span class="posted-on"><?php echo esc_html(get_the_date()); ?></span>
        </div>
    </header>

    <div class="entry-summary">
        <?php the_excerpt(); ?>
    </div>
</article>
