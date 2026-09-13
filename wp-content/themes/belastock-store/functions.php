<?php
if (!defined('ABSPATH')) exit;

function belastock_store_setup(): void {
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
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

add_filter('loop_shop_columns', static fn() => 4);
add_filter('loop_shop_per_page', static fn() => 12, 20);

add_action('after_switch_theme', function () {
    if (get_option('belastock_theme_initialized')) return;
    $pages = [
        'Sobre a Bela Stock' => 'Criações para vestir, usar e levar com você.',
        'Trocas e devoluções' => 'Consulte aqui as condições de troca e devolução da loja.',
        'Política de privacidade' => 'Esta página apresenta as regras de privacidade e tratamento de dados da loja.',
    ];
    foreach ($pages as $title => $content) {
        if (!get_page_by_title($title)) {
            wp_insert_post(['post_type'=>'page','post_status'=>'publish','post_title'=>$title,'post_content'=>$content]);
        }
    }
    update_option('belastock_theme_initialized', 1);
});
