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

if (class_exists('WC_Install')) {
    WC_Install::create_pages();
}

BelaStock_Operations::register_mockup_post_type();
BelaStock_Operations::bootstrap_catalog();
update_option('belastock_operations_version', BelaStock_Operations::VERSION, false);

$wc_pages = [
    'woocommerce_shop_page_id' => ['slug'=>'loja', 'label'=>'Loja'],
    'woocommerce_cart_page_id' => ['slug'=>'carrinho', 'label'=>'Carrinho'],
    'woocommerce_checkout_page_id' => ['slug'=>'finalizar-compra', 'label'=>'Finalizar compra'],
    'woocommerce_myaccount_page_id' => ['slug'=>'minha-conta', 'label'=>'Minha conta'],
];
foreach ($wc_pages as $option => $spec) {
    $id = absint(get_option($option));
    if (!$id || get_post_type($id) !== 'page') {
        fwrite(STDERR, "Página WooCommerce ausente: {$option}\n");
        exit(5);
    }
    $post = get_post($id);
    if (!$post) {
        fwrite(STDERR, "Página WooCommerce inválida: {$option}\n");
        exit(6);
    }
    $update = ['ID'=>$id, 'post_status'=>'publish'];
    if ((string)$post->post_name !== $spec['slug']) $update['post_name'] = $spec['slug'];
    wp_update_post($update);
}

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

flush_rewrite_rules(true);
if (class_exists('Elementor\\Plugin')) {
    try { Elementor\Plugin::$instance->files_manager->clear_cache(); } catch (Throwable $e) {}
}

printf("OPERATIONS=ok\n");
printf("CATALOG_CATEGORIES=%d\n", count($required_categories));
printf("CATALOG_ATTRIBUTES=tamanho,cor,modelo\n");
printf("MOCKUP_LIBRARY=ready\n");
printf("PERSONALIZATION_BRIEF=ready\n");
printf("WOOCOMMERCE_ROUTES=loja,carrinho,finalizar-compra,minha-conta\n");
printf("OPERATIONAL_PAGES=personalizacao,atacado,perguntas-frequentes,rastrear-pedido\n");
