<?php
get_header();
while (have_posts()) {
    the_post();
    $is_elementor = get_post_meta(get_the_ID(), '_elementor_edit_mode', true) === 'builder';
    $elementor_data = get_post_meta(get_the_ID(), '_elementor_data', true);
    if ($is_elementor && !empty($elementor_data) && class_exists('Elementor\\Plugin')) {
        echo '<main class="belastock-elementor-product">';
        the_content();
        echo '</main>';
    } else {
        echo '<main class="content-area"><div class="bs-wrap">';
        woocommerce_content();
        echo '</div></main>';
    }
}
get_footer();
