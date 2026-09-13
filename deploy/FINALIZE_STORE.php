<?php
if (!defined('ABSPATH')) {
    fwrite(STDERR, "WordPress nao carregado.\n");
    exit(1);
}
if (!class_exists('WooCommerce')) {
    fwrite(STDERR, "WooCommerce nao esta carregado.\n");
    exit(1);
}
if (class_exists('WC_Install')) {
    WC_Install::create_pages();
}

function belastock_ensure_page(string $title, string $slug, string $content): int {
    $page = get_page_by_path($slug, OBJECT, 'page');
    if (!$page) {
        $id = wp_insert_post(['post_type'=>'page','post_status'=>'publish','post_title'=>$title,'post_name'=>$slug,'post_content'=>$content], true);
        if (is_wp_error($id)) throw new RuntimeException($id->get_error_message());
        return (int)$id;
    }
    $placeholder_markers = ['Consulte aqui as condições','Esta página apresenta as regras','Esta pagina apresenta as regras','Criações para vestir, usar e levar com você.','Criacoes para vestir, usar e levar com voce.'];
    $should_update = trim((string)$page->post_content) === '';
    foreach ($placeholder_markers as $marker) {
        if (strpos((string)$page->post_content, $marker) !== false) { $should_update = true; break; }
    }
    if ($should_update) {
        wp_update_post(['ID'=>$page->ID,'post_status'=>'publish','post_title'=>$title,'post_content'=>$content]);
    } elseif ($page->post_status !== 'publish') {
        wp_update_post(['ID'=>$page->ID,'post_status'=>'publish']);
    }
    return (int)$page->ID;
}

function belastock_ensure_attribute(string $name, string $slug, array $terms): void {
    $found = false;
    foreach ((array)wc_get_attribute_taxonomies() as $attribute) {
        if ((string)$attribute->attribute_name === $slug) { $found = true; break; }
    }
    if (!$found) {
        $result = wc_create_attribute(['name'=>$name,'slug'=>$slug,'type'=>'select','order_by'=>'menu_order','has_archives'=>false]);
        if (is_wp_error($result)) throw new RuntimeException($result->get_error_message());
        delete_transient('wc_attribute_taxonomies');
        if (class_exists('WC_Cache_Helper')) WC_Cache_Helper::invalidate_cache_group('woocommerce-attributes');
    }
    $taxonomy = wc_attribute_taxonomy_name($slug);
    if (!taxonomy_exists($taxonomy)) {
        register_taxonomy($taxonomy, ['product'], ['hierarchical'=>false,'label'=>$name,'public'=>false,'show_ui'=>false,'query_var'=>true,'rewrite'=>false]);
    }
    foreach ($terms as $term) {
        if (!term_exists($term, $taxonomy)) {
            $created = wp_insert_term($term, $taxonomy);
            if (is_wp_error($created)) throw new RuntimeException($created->get_error_message());
        }
    }
}

function belastock_elementor_data(array $widgets): array {
    $elements = [];
    $n = 1;
    foreach ($widgets as $widget) {
        $elements[] = [
            'id' => 'bsw' . str_pad((string)$n, 5, '0', STR_PAD_LEFT),
            'elType' => 'widget',
            'widgetType' => $widget['type'],
            'settings' => $widget['settings'] ?? [],
            'elements' => [],
        ];
        $n++;
    }
    return [[
        'id' => 'bsc0001',
        'elType' => 'container',
        'settings' => ['content_width' => 'full', 'padding' => ['unit'=>'px','top'=>'0','right'=>'0','bottom'=>'0','left'=>'0','isLinked'=>true]],
        'elements' => $elements,
    ]];
}

function belastock_ensure_elementor_page(string $title, string $slug, array $widgets): int {
    $page = get_page_by_path($slug, OBJECT, 'page');
    if (!$page) {
        $id = wp_insert_post(['post_type'=>'page','post_status'=>'publish','post_title'=>$title,'post_name'=>$slug,'post_content'=>''], true);
        if (is_wp_error($id)) throw new RuntimeException($id->get_error_message());
        $page_id = (int)$id;
    } else {
        $page_id = (int)$page->ID;
        if ($page->post_status !== 'publish') wp_update_post(['ID'=>$page_id,'post_status'=>'publish']);
    }
    if (!get_post_meta($page_id, '_elementor_data', true)) {
        update_post_meta($page_id, '_elementor_data', wp_slash(wp_json_encode(belastock_elementor_data($widgets))));
    }
    update_post_meta($page_id, '_elementor_edit_mode', 'builder');
    update_post_meta($page_id, '_elementor_template_type', 'wp-page');
    if (defined('ELEMENTOR_VERSION')) update_post_meta($page_id, '_elementor_version', ELEMENTOR_VERSION);
    return $page_id;
}

$about = belastock_ensure_page('Sobre a Bela Stock','sobre-a-bela-stock','<h2>Bela Stock</h2><p>A Bela Stock reúne camisetas, bonés e adesivos com identidade própria. A loja foi preparada para apresentar cada peça em fotografias reais, incluindo frente, verso, lateral e detalhes.</p><p>Os produtos, variações, disponibilidade e prazos apresentados em cada página prevalecem no momento da compra.</p>');
$shipping = belastock_ensure_page('Entregas e frete','entregas-e-frete','<h2>Entregas e frete</h2><p>O frete é calculado a partir do CEP informado no carrinho ou no checkout, conforme os serviços de entrega habilitados para o destino. Quando disponíveis, serão apresentadas as modalidades, valores e estimativas de prazo antes da confirmação do pedido.</p><p>Após a postagem, o acompanhamento será disponibilizado conforme o serviço de transporte utilizado. Confira cuidadosamente o endereço antes de concluir a compra.</p>');
$returns = belastock_ensure_page('Trocas e devoluções','trocas-e-devolucoes','<h2>Trocas e devoluções</h2><p>Solicitações de troca ou devolução devem informar o número do pedido e o motivo do contato. Produtos devem ser preservados nas condições recebidas, ressalvadas as hipóteses de defeito ou demais direitos previstos na legislação aplicável.</p><p>Produtos personalizados podem exigir análise específica quando a produção já tiver sido iniciada ou quando houver aprovação prévia de arte, sem prejuízo dos direitos legalmente assegurados ao consumidor.</p>');
$privacy = belastock_ensure_page('Política de privacidade','politica-de-privacidade','<h2>Política de privacidade</h2><p>Os dados informados na loja são utilizados para processar pedidos, pagamentos, entregas, atendimento, prevenção a fraudes e cumprimento de obrigações legais. Dados de pagamento podem ser processados diretamente pelos provedores habilitados no checkout.</p><p>Informações necessárias à entrega podem ser compartilhadas com operadores logísticos e transportadores.</p><p>Para assuntos relacionados a dados pessoais, utilize o canal de contato informado neste site.</p>');
$terms = belastock_ensure_page('Termos e condições','termos-e-condicoes','<h2>Termos e condições</h2><p>Ao realizar um pedido, o cliente confirma os produtos, quantidades, variações, endereço, forma de entrega e forma de pagamento apresentados no checkout. O pedido fica sujeito à confirmação do pagamento e à disponibilidade indicada pela loja.</p><p>Preços, promoções e condições válidas são os exibidos no momento da conclusão da compra.</p><p>Estes termos não restringem direitos garantidos pela legislação brasileira de proteção ao consumidor.</p>');
$contact = belastock_ensure_page('Contato','contato','<h2>Fale com a Bela Stock</h2><p>Para dúvidas sobre produtos, pedidos, entregas, trocas ou pagamentos, envie um e-mail para <a href="mailto:contato@belastock.com.br">contato@belastock.com.br</a>. Ao falar sobre uma compra, informe o número do pedido.</p>');

update_option('wp_page_for_privacy_policy', $privacy);
update_option('woocommerce_terms_page_id', $terms);
update_option('woocommerce_enable_guest_checkout', 'yes');
update_option('woocommerce_enable_checkout_login_reminder', 'yes');
update_option('woocommerce_enable_myaccount_registration', 'yes');
update_option('woocommerce_enable_signup_and_login_from_checkout', 'yes');
update_option('woocommerce_registration_generate_username', 'yes');
update_option('woocommerce_registration_generate_password', 'yes');
update_option('woocommerce_cart_redirect_after_add', 'no');
update_option('woocommerce_currency', 'BRL');
update_option('woocommerce_currency_pos', 'left_space');
update_option('woocommerce_price_decimal_sep', ',');
update_option('woocommerce_price_thousand_sep', '.');
update_option('woocommerce_price_num_decimals', '2');
update_option('woocommerce_manage_stock', 'yes');
update_option('woocommerce_hold_stock_minutes', '60');
update_option('woocommerce_notify_low_stock', 'yes');
update_option('woocommerce_notify_no_stock', 'yes');
update_option('woocommerce_stock_email_recipient', 'contato@belastock.com.br');
update_option('woocommerce_email_from_name', 'Bela Stock');
update_option('woocommerce_email_from_address', 'contato@belastock.com.br');
update_option('woocommerce_allowed_countries', 'specific');
update_option('woocommerce_specific_allowed_countries', ['BR']);
update_option('woocommerce_ship_to_countries', ['BR']);
update_option('woocommerce_ship_to_destination', 'shipping');
update_option('woocommerce_coming_soon', 'no');

foreach (['shop','cart','checkout','myaccount'] as $wc_page) {
    $id = wc_get_page_id($wc_page);
    if ($id > 0 && get_post_status($id) !== 'publish') wp_update_post(['ID'=>$id,'post_status'=>'publish']);
}

belastock_ensure_attribute('Tamanho','tamanho',['PP','P','M','G','GG','XG']);
belastock_ensure_attribute('Cor','cor',['Preto','Branco','Cinza','Azul-marinho','Roxo']);

if (get_option('belastock_quantity_discount_tiers', null) === null) {
    update_option('belastock_quantity_discount_tiers', [
        ['min'=>1,'discount'=>0],['min'=>2,'discount'=>5],['min'=>5,'discount'=>10],['min'=>10,'discount'=>15],['min'=>20,'discount'=>20],['min'=>50,'discount'=>25],
    ]);
}

$header_page = belastock_ensure_elementor_page('Bela Stock — Cabeçalho Elementor','bs-header',[
    ['type'=>'belastock-announcement','settings'=>[]],
    ['type'=>'belastock-header','settings'=>[]],
]);
$footer_page = belastock_ensure_elementor_page('Bela Stock — Rodapé Elementor','bs-footer',[
    ['type'=>'belastock-footer','settings'=>[]],
]);
$home_page = belastock_ensure_elementor_page('Bela Stock — Capa Elementor','capa-bela-stock',[
    ['type'=>'belastock-hero','settings'=>[]],
    ['type'=>'belastock-category-cards','settings'=>[]],
    ['type'=>'belastock-product-cards','settings'=>['limit'=>8,'columns'=>'4','orderby'=>'date']],
]);
update_option('belastock_header_page_id', $header_page);
update_option('belastock_footer_page_id', $footer_page);
update_option('show_on_front', 'page');
update_option('page_on_front', $home_page);

if (class_exists('BelaStock_Core')) {
    foreach (get_posts(['post_type'=>'product','post_status'=>['publish','draft','pending'],'numberposts'=>-1,'fields'=>'ids']) as $product_id) {
        BelaStock_Core::seed_elementor_product((int)$product_id);
    }
}

flush_rewrite_rules(false);

printf("FINALIZER=ok\n");
printf("PAGE_ABOUT=%d\n", $about);
printf("PAGE_SHIPPING=%d\n", $shipping);
printf("PAGE_RETURNS=%d\n", $returns);
printf("PAGE_PRIVACY=%d\n", $privacy);
printf("PAGE_TERMS=%d\n", $terms);
printf("PAGE_CONTACT=%d\n", $contact);
printf("ELEMENTOR_HEADER_PAGE=%d\n", $header_page);
printf("ELEMENTOR_FOOTER_PAGE=%d\n", $footer_page);
printf("ELEMENTOR_HOME_PAGE=%d\n", $home_page);
printf("ATTRIBUTES=tamanho,cor\n");
printf("DISCOUNTS=1:0,2:5,5:10,10:15,20:20,50:25\n");
printf("STORE_VISIBILITY=live\n");
