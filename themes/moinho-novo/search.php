<?php
get_header();
?>

<header class="search-header">
    <h1 class="search-title">
        <?php
        printf(
            /* translators: %s: search query */
            esc_html__('Search results for: %s', 'moinho-novo'),
            '<span>' . esc_html(get_search_query()) . '</span>'
        );
        ?>
    </h1>
</header>

<?php if (have_posts()) : ?>
    <?php while (have_posts()) : the_post(); ?>
        <?php get_template_part('template-parts/content', 'search'); ?>
    <?php endwhile; ?>

    <div class="pagination">
        <?php the_posts_pagination(); ?>
    </div>
<?php else : ?>
    <?php get_template_part('template-parts/content', 'none'); ?>
<?php endif; ?>

<?php
get_footer();
