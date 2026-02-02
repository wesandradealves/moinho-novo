<?php
get_header();
?>

<?php if (is_home() && ! is_front_page()) : ?>
    <header class="home-header">
        <h1 class="home-title"><?php single_post_title(); ?></h1>
    </header>
<?php endif; ?>

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
