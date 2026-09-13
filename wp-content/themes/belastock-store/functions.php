<?php
if (!defined('ABSPATH')) exit;

function belastock_store_setup(): void {
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('custom-logo');
    add_theme_support('woocommerce');
    add_theme_support('wc-product-gallery-zoom');
    add_theme_support('wc-product-gallery-lightbox');
    add_theme_support('wc-product-gallery-slider');
    register_nav_menus(['primary' => 'Menu principal']);
}
add_action('after_setup_theme', 'belastock_store_setup');

function belastock_store_assets(): void {
    wp_enqueue_style('belastock-store', get_stylesheet_uri(), [], wp_get_theme()->get('Version'));
}
add_action('wp_enqueue_scripts', 'belastock_store_assets');

function belastock_cart_count(): int {
    return function_exists('WC') && WC()->cart ? WC()->cart->get_cart_contents_count() : 0;
}

function belastock_render_elementor_area(string $option_name): bool {
    $page_id = absint(get_option($option_name));
    if (!$page_id || get_post_status($page_id) !== 'publish' || get_queried_object_id() === $page_id) {
        return false;
    }
    if (class_exists('Elementor\\Plugin')) {
        $content = \Elementor\Plugin::$instance->frontend->get_builder_content_for_display($page_id, true);
        if (is_string($content) && trim($content) !== '') {
            echo $content;
            return true;
        }
    }
    $post = get_post($page_id);
    if ($post && trim((string)$post->post_content) !== '') {
        echo apply_filters('the_content', $post->post_content);
        return true;
    }
    return false;
}

function belastock_logo_url(): string {
    return get_theme_file_uri('/assets/belastock-logo.webp');
}

add_filter('loop_shop_columns', static fn() => 4);
add_filter('loop_shop_per_page', static fn() => 12, 20);

add_action('after_switch_theme', function () {
    update_option('belastock_theme_initialized', 1);
});
