<?php
if (!defined('ABSPATH')) { fwrite(STDERR, "WordPress nao carregado.\n"); exit(1); }

$categories = [
    'camisetas' => 'Camisetas',
    'manga-longa' => 'Manga Longa',
    'regatas' => 'Regatas',
    'baby-look' => 'Baby Look',
    'machao' => 'Machão',
    'moletons' => 'Moletons',
    'bones' => 'Bonés',
    'ecobags' => 'Ecobags',
    'adesivos' => 'Adesivos',
    'canecas' => 'Canecas',
];
foreach ($categories as $slug => $name) {
    if (!term_exists($slug, 'product_cat')) {
        $r = wp_insert_term($name, 'product_cat', ['slug' => $slug]);
        if (is_wp_error($r)) throw new RuntimeException($r->get_error_message());
    }
}

update_option('woocommerce_thumbnail_image_width', 720);
update_option('woocommerce_single_image_width', 1200);
update_option('woocommerce_thumbnail_cropping', '1:1');
update_option('belastock_visual_version', '4.0.0');

$types = get_option('elementor_cpt_support', ['page','post']);
$types = is_array($types) ? $types : ['page','post'];
if (!in_array('product', $types, true)) $types[] = 'product';
update_option('elementor_cpt_support', array_values(array_unique($types)));

if (class_exists('Elementor\\Plugin')) {
    try { \Elementor\Plugin::$instance->files_manager->clear_cache(); } catch (Throwable $e) {}
}
flush_rewrite_rules(false);

printf("BELASTOCK_VISUAL_V4=ok\n");
printf("CATEGORIES=%d\n", count($categories));
printf("WC_THUMBNAIL_WIDTH=%s\n", get_option('woocommerce_thumbnail_image_width'));
printf("WC_SINGLE_WIDTH=%s\n", get_option('woocommerce_single_image_width'));
