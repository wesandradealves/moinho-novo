<?php
get_header();
?>

<header class="archive-header">
    <h1 class="archive-title"><?php the_archive_title(); ?></h1>
    <?php the_archive_description('<div class="archive-description">', '</div>'); ?>
</header>

<?php if (have_posts()) : ?>
    <?php while (have_posts()) : the_post(); ?>
        <?php get_template_part('template-parts/content', get_post_type()); ?>
    <?php endwhile; ?>

    <div class="pagination">
        <?php the_posts_pagination(); ?>
    </div>
<?php else : ?>
    <?php get_template_part('template-parts/content', 'none'); ?>
<?php endif; ?>

<?php
get_footer();
