<?php
if (!defined('ABSPATH')) exit;

if (!class_exists('BelaStock_Operations')) {
    fwrite(STDERR, "BelaStock_Operations não carregado.\n");
    exit(1);
}
if (!class_exists('WooCommerce')) {
    fwrite(STDERR, "WooCommerce não carregado.\n");
    exit(1);
}

BelaStock_Operations::register_mockup_post_type();
BelaStock_Operations::bootstrap_catalog();
update_option('belastock_operations_version', BelaStock_Operations::VERSION, false);

$required_categories = ['camisetas','manga-longa','regatas','baby-look','machao','moletons','bones','ecobags','adesivos','personalizados'];
foreach ($required_categories as $slug) {
    if (!term_exists($slug, 'product_cat')) {
        fwrite(STDERR, "Categoria ausente: {$slug}\n");
        exit(2);
    }
}
$attrs = array_map(static fn($a) => (string)$a->attribute_name, (array)wc_get_attribute_taxonomies());
foreach (['tamanho','cor','modelo'] as $attr) {
    if (!in_array($attr, $attrs, true)) {
        fwrite(STDERR, "Atributo ausente: {$attr}\n");
        exit(3);
    }
}
foreach (['personalizacao','atacado','perguntas-frequentes','rastrear-pedido'] as $slug) {
    $page = get_page_by_path($slug, OBJECT, 'page');
    if (!$page || $page->post_status !== 'publish') {
        fwrite(STDERR, "Página operacional ausente: {$slug}\n");
        exit(4);
    }
}

flush_rewrite_rules(false);
printf("OPERATIONS=ok\n");
printf("CATALOG_CATEGORIES=%d\n", count($required_categories));
printf("CATALOG_ATTRIBUTES=tamanho,cor,modelo\n");
printf("MOCKUP_LIBRARY=ready\n");
printf("PERSONALIZATION_BRIEF=ready\n");
printf("OPERATIONAL_PAGES=personalizacao,atacado,perguntas-frequentes,rastrear-pedido\n");
