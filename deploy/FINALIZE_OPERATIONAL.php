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
$operational_slugs = ['personalizacao','atacado','perguntas-frequentes','rastrear-pedido'];
foreach ($operational_slugs as $slug) {
    $page = get_page_by_path($slug, OBJECT, 'page');
    if (!$page || $page->post_status !== 'publish') {
        fwrite(STDERR, "Página operacional ausente: {$slug}\n");
        exit(4);
    }
}

/*
 * O vhost atual entrega a raiz, mas não possui fallback nginx para index.php.
 * Mantemos WordPress em permalinks simples (que funcionam sem rewrite) e criamos
 * pontes físicas somente para as rotas amigáveis fixas usadas pela loja.
 * Produtos e demais URLs geradas pelo WordPress passam a usar query string.
 */
update_option('permalink_structure', '');
update_option('category_base', '');
update_option('tag_base', '');
flush_rewrite_rules(true);

$docroot = untrailingslashit(ABSPATH);
$write_bridge = static function (string $relative, string $target) use ($docroot): void {
    $relative = trim($relative, '/');
    if ($relative === '' || strpos($relative, '..') !== false) return;
    $dir = $docroot . '/' . $relative;
    if (!is_dir($dir) && !wp_mkdir_p($dir)) {
        throw new RuntimeException('Falha ao criar ponte de rota: ' . $relative);
    }
    $target = '/' . ltrim($target, '/');
    $code = "<?php\nheader('Location: " . addslashes($target) . "', true, 302);\nexit;\n";
    if (file_put_contents($dir . '/index.php', $code, LOCK_EX) === false) {
        throw new RuntimeException('Falha ao gravar ponte de rota: ' . $relative);
    }
};

foreach ($wc_pages as $option => $spec) {
    $id = absint(get_option($option));
    $write_bridge($spec['slug'], '?page_id=' . $id);
}

$fixed_page_slugs = [
    'personalizacao','atacado','perguntas-frequentes','rastrear-pedido',
    'contato','sobre-a-bela-stock','entregas-e-frete','trocas-e-devolucoes',
    'politica-de-privacidade','termos-e-condicoes'
];
foreach ($fixed_page_slugs as $slug) {
    $page = get_page_by_path($slug, OBJECT, 'page');
    if ($page && $page->post_status === 'publish') {
        $write_bridge($slug, '?page_id=' . absint($page->ID));
    }
}

foreach ($required_categories as $slug) {
    $write_bridge('categoria-produto/' . $slug, '?product_cat=' . rawurlencode($slug));
}

if (class_exists('Elementor\\Plugin')) {
    try { Elementor\Plugin::$instance->files_manager->clear_cache(); } catch (Throwable $e) {}
}
if (function_exists('wp_cache_flush')) wp_cache_flush();

printf("OPERATIONS=ok\n");
printf("CATALOG_CATEGORIES=%d\n", count($required_categories));
printf("CATALOG_ATTRIBUTES=tamanho,cor,modelo\n");
printf("MOCKUP_LIBRARY=ready\n");
printf("PERSONALIZATION_BRIEF=ready\n");
printf("PERMALINK_MODE=simple-no-nginx-rewrite-dependency\n");
printf("ROUTE_BRIDGES=woocommerce,pages,categories\n");
printf("WOOCOMMERCE_ROUTES=loja,carrinho,finalizar-compra,minha-conta\n");
printf("OPERATIONAL_PAGES=personalizacao,atacado,perguntas-frequentes,rastrear-pedido\n");
