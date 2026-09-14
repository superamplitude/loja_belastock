<?php
if (!defined('ABSPATH')) exit;

/**
 * Bela Stock Operations v1.0.0
 * Camada operacional da loja: estrutura de catálogo, biblioteca de mockups,
 * personalização de produto e painel de prontidão.
 */
final class BelaStock_Operations {
    public const VERSION = '1.0.0';
    private const OPTION_VERSION = 'belastock_operations_version';
    private const PRODUCT_PERSONALIZABLE = '_belastock_personalizable';
    private const PRODUCT_BASE_MOCKUPS = '_belastock_base_mockups';
    private const MOCKUP_KIND = '_belastock_mockup_kind';
    private const MOCKUP_VIEW = '_belastock_mockup_view';
    private const MOCKUP_COLOR = '_belastock_mockup_color';
    private const MOCKUP_NOTES = '_belastock_mockup_notes';

    private const PRODUCT_KINDS = [
        'camiseta' => 'Camiseta manga curta',
        'manga-longa' => 'Camiseta manga longa',
        'regata' => 'Regata',
        'machao' => 'Machão',
        'baby-look' => 'Baby Look',
        'moletom' => 'Moletom',
        'bone' => 'Boné',
        'ecobag' => 'Ecobag',
        'adesivo' => 'Adesivo',
    ];

    private const VIEWS = [
        'front' => 'Frente',
        'back' => 'Verso',
        'side' => 'Lateral',
        'detail' => 'Detalhe',
    ];

    private const COLORS = [
        'branco' => 'Branco',
        'preto' => 'Preto',
        'roxo' => 'Roxo',
        'amarelo' => 'Amarelo',
        'verde' => 'Verde',
        'azul' => 'Azul',
        'cinza' => 'Cinza',
        'natural' => 'Natural / cru',
    ];

    public static function init(): void {
        add_action('init', [__CLASS__, 'register_mockup_post_type'], 5);
        add_action('init', [__CLASS__, 'bootstrap_once'], 40);
        add_action('add_meta_boxes', [__CLASS__, 'register_meta_boxes']);
        add_action('save_post_bs_mockup', [__CLASS__, 'save_mockup'], 10, 2);
        add_action('save_post_product', [__CLASS__, 'save_product'], 30, 2);
        add_filter('manage_bs_mockup_posts_columns', [__CLASS__, 'mockup_columns']);
        add_action('manage_bs_mockup_posts_custom_column', [__CLASS__, 'mockup_column_content'], 10, 2);
        add_action('admin_notices', [__CLASS__, 'admin_notices']);
        add_action('admin_menu', [__CLASS__, 'admin_menu'], 95);

        add_action('woocommerce_before_add_to_cart_button', [__CLASS__, 'render_personalization_field'], 8);
        add_filter('woocommerce_add_cart_item_data', [__CLASS__, 'capture_personalization'], 20, 4);
        add_filter('woocommerce_get_item_data', [__CLASS__, 'cart_item_data'], 20, 2);
        add_action('woocommerce_checkout_create_order_line_item', [__CLASS__, 'order_line_meta'], 20, 4);

        add_filter('big_image_size_threshold', static fn() => 3200);
        add_filter('jpeg_quality', static fn() => 92);
        add_filter('wp_editor_set_quality', static fn() => 92);
    }

    public static function register_mockup_post_type(): void {
        register_post_type('bs_mockup', [
            'labels' => [
                'name' => 'Biblioteca de Mockups',
                'singular_name' => 'Mockup base',
                'add_new' => 'Adicionar mockup',
                'add_new_item' => 'Adicionar mockup base',
                'edit_item' => 'Editar mockup base',
                'new_item' => 'Novo mockup base',
                'view_item' => 'Ver mockup base',
                'search_items' => 'Buscar mockups',
                'not_found' => 'Nenhum mockup encontrado',
            ],
            'public' => false,
            'show_ui' => true,
            'show_in_menu' => 'edit.php?post_type=product',
            'show_in_rest' => false,
            'supports' => ['title', 'thumbnail'],
            'menu_icon' => 'dashicons-format-image',
            'capability_type' => 'post',
            'map_meta_cap' => true,
        ]);
    }

    public static function bootstrap_once(): void {
        if (!class_exists('WooCommerce') || !function_exists('wc_get_attribute_taxonomies')) return;
        if ((string)get_option(self::OPTION_VERSION, '') === self::VERSION) return;
        self::bootstrap_catalog();
        update_option(self::OPTION_VERSION, self::VERSION, false);
    }

    public static function bootstrap_catalog(): void {
        self::ensure_categories();
        self::ensure_attribute('Tamanho', 'tamanho', ['PP','P','M','G','GG','XG','XGG','Único']);
        self::ensure_attribute('Cor', 'cor', ['Branco','Preto','Roxo','Amarelo','Verde','Azul','Cinza','Natural']);
        self::ensure_attribute('Modelo', 'modelo', ['Unissex','Feminino','Masculino','Infantil']);

        $options = [
            'woocommerce_currency' => 'BRL',
            'woocommerce_default_country' => 'BR',
            'woocommerce_allowed_countries' => 'specific',
            'woocommerce_specific_allowed_countries' => ['BR'],
            'woocommerce_ship_to_countries' => ['BR'],
            'woocommerce_manage_stock' => 'yes',
            'woocommerce_hold_stock_minutes' => '60',
            'woocommerce_enable_guest_checkout' => 'yes',
            'woocommerce_enable_myaccount_registration' => 'yes',
            'woocommerce_enable_signup_and_login_from_checkout' => 'yes',
            'woocommerce_registration_generate_username' => 'yes',
            'woocommerce_registration_generate_password' => 'yes',
            'woocommerce_enable_coupons' => 'yes',
            'woocommerce_thumbnail_image_width' => '800',
            'woocommerce_single_image_width' => '1600',
            'woocommerce_gallery_thumbnail_image_width' => '360',
            'woocommerce_thumbnail_cropping' => '1:1',
            'medium_large_size_w' => 1200,
            'large_size_w' => 1800,
            'large_size_h' => 1800,
        ];
        foreach ($options as $key => $value) update_option($key, $value);

        self::ensure_page('Personalização', 'personalizacao', '<h2>Personalização Bela Stock</h2><p>Escolha um produto compatível, informe as observações do pedido e finalize a compra. A equipe valida os detalhes de produção antes da execução quando houver personalização.</p><p>As opções disponíveis dependem do produto, cor, tamanho, estoque e área de aplicação.</p>');
        self::ensure_page('Atacado', 'atacado', '<h2>Atacado e pedidos em quantidade</h2><p>A Bela Stock trabalha com descontos progressivos por quantidade. As faixas vigentes são exibidas na página dos produtos e aplicadas automaticamente no carrinho.</p><p>Para necessidades especiais, entre em contato antes de concluir o pedido.</p>');
        self::ensure_page('Perguntas frequentes', 'perguntas-frequentes', '<h2>Perguntas frequentes</h2><h3>Como funcionam os descontos?</h3><p>O desconto progressivo é calculado automaticamente conforme a quantidade de cada produto no carrinho.</p><h3>Posso personalizar?</h3><p>Produtos marcados como personalizáveis exibem um campo de briefing na própria página do produto.</p><h3>Como acompanho meu pedido?</h3><p>Use a área Minha Conta ou a página de rastreamento.</p>');
        self::ensure_page('Rastrear pedido', 'rastrear-pedido', '[woocommerce_order_tracking]');
        flush_rewrite_rules(false);
    }

    private static function ensure_categories(): void {
        if (!taxonomy_exists('product_cat')) return;
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
            'personalizados' => 'Personalizados',
        ];
        foreach ($categories as $slug => $name) {
            if (!term_exists($slug, 'product_cat')) {
                wp_insert_term($name, 'product_cat', ['slug' => $slug]);
            }
        }
    }

    private static function ensure_attribute(string $name, string $slug, array $terms): void {
        $found = false;
        foreach ((array)wc_get_attribute_taxonomies() as $attribute) {
            if ((string)$attribute->attribute_name === $slug) { $found = true; break; }
        }
        if (!$found && function_exists('wc_create_attribute')) {
            $result = wc_create_attribute(['name'=>$name,'slug'=>$slug,'type'=>'select','order_by'=>'menu_order','has_archives'=>false]);
            if (!is_wp_error($result)) {
                delete_transient('wc_attribute_taxonomies');
                if (class_exists('WC_Cache_Helper')) WC_Cache_Helper::invalidate_cache_group('woocommerce-attributes');
            }
        }
        $taxonomy = wc_attribute_taxonomy_name($slug);
        if (!taxonomy_exists($taxonomy)) {
            register_taxonomy($taxonomy, ['product'], ['hierarchical'=>false,'label'=>$name,'public'=>false,'show_ui'=>true,'query_var'=>true,'rewrite'=>false]);
        }
        foreach ($terms as $term) {
            if (!term_exists($term, $taxonomy)) wp_insert_term($term, $taxonomy);
        }
    }

    private static function ensure_page(string $title, string $slug, string $content): int {
        $page = get_page_by_path($slug, OBJECT, 'page');
        if ($page) {
            if ($page->post_status !== 'publish') wp_update_post(['ID'=>$page->ID,'post_status'=>'publish']);
            return (int)$page->ID;
        }
        $id = wp_insert_post(['post_type'=>'page','post_status'=>'publish','post_title'=>$title,'post_name'=>$slug,'post_content'=>$content], true);
        return is_wp_error($id) ? 0 : (int)$id;
    }

    public static function register_meta_boxes(): void {
        add_meta_box('bs-mockup-details', 'Bela Stock — Dados do mockup base', [__CLASS__, 'render_mockup_box'], 'bs_mockup', 'normal', 'high');
        add_meta_box('bs-product-operations', 'Bela Stock — Configuração operacional', [__CLASS__, 'render_product_box'], 'product', 'normal', 'default');
    }

    public static function render_mockup_box(WP_Post $post): void {
        wp_nonce_field('belastock_mockup_save', 'belastock_mockup_nonce');
        $kind = (string)get_post_meta($post->ID, self::MOCKUP_KIND, true);
        $view = (string)get_post_meta($post->ID, self::MOCKUP_VIEW, true);
        $color = (string)get_post_meta($post->ID, self::MOCKUP_COLOR, true);
        $notes = (string)get_post_meta($post->ID, self::MOCKUP_NOTES, true);
        echo '<p><strong>Use uma fotografia real SEM logo e SEM estampa como Imagem destacada.</strong> A imagem deve ser JPG/JPEG ou WEBP e ter pelo menos 1200 px no maior lado.</p>';
        echo '<table class="form-table"><tbody>';
        self::select_row('Tipo de produto', 'belastock_mockup_kind', $kind, self::PRODUCT_KINDS);
        self::select_row('Vista', 'belastock_mockup_view', $view, self::VIEWS);
        self::select_row('Cor', 'belastock_mockup_color', $color, self::COLORS);
        echo '<tr><th><label for="belastock_mockup_notes">Observações</label></th><td><textarea class="large-text" rows="3" id="belastock_mockup_notes" name="belastock_mockup_notes">'.esc_textarea($notes).'</textarea></td></tr>';
        echo '</tbody></table>';
    }

    private static function select_row(string $label, string $name, string $current, array $options): void {
        echo '<tr><th><label for="'.esc_attr($name).'">'.esc_html($label).'</label></th><td><select id="'.esc_attr($name).'" name="'.esc_attr($name).'">';
        echo '<option value="">Selecione</option>';
        foreach ($options as $value => $text) echo '<option value="'.esc_attr($value).'" '.selected($current, $value, false).'>'.esc_html($text).'</option>';
        echo '</select></td></tr>';
    }

    public static function save_mockup(int $post_id, WP_Post $post): void {
        if (!isset($_POST['belastock_mockup_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['belastock_mockup_nonce'])), 'belastock_mockup_save')) return;
        if (wp_is_post_revision($post_id) || !current_user_can('edit_post', $post_id)) return;

        $kind = sanitize_key(wp_unslash($_POST['belastock_mockup_kind'] ?? ''));
        $view = sanitize_key(wp_unslash($_POST['belastock_mockup_view'] ?? ''));
        $color = sanitize_key(wp_unslash($_POST['belastock_mockup_color'] ?? ''));
        $notes = sanitize_textarea_field(wp_unslash($_POST['belastock_mockup_notes'] ?? ''));
        update_post_meta($post_id, self::MOCKUP_KIND, array_key_exists($kind, self::PRODUCT_KINDS) ? $kind : '');
        update_post_meta($post_id, self::MOCKUP_VIEW, array_key_exists($view, self::VIEWS) ? $view : '');
        update_post_meta($post_id, self::MOCKUP_COLOR, array_key_exists($color, self::COLORS) ? $color : '');
        update_post_meta($post_id, self::MOCKUP_NOTES, $notes);

        $thumb_id = get_post_thumbnail_id($post_id);
        if ($thumb_id) {
            $mime = (string)get_post_mime_type($thumb_id);
            $meta = wp_get_attachment_metadata($thumb_id);
            $largest = max((int)($meta['width'] ?? 0), (int)($meta['height'] ?? 0));
            if (!in_array($mime, ['image/jpeg','image/webp'], true) || $largest < 1200) {
                delete_post_thumbnail($post_id);
                set_transient('belastock_mockup_notice_' . get_current_user_id(), 'O mockup foi salvo, mas a imagem destacada foi removida porque não atende ao padrão: JPG/JPEG ou WEBP e mínimo de 1200 px.', 60);
            }
        }
    }

    public static function render_product_box(WP_Post $post): void {
        wp_nonce_field('belastock_product_ops_save', 'belastock_product_ops_nonce');
        $personalizable = get_post_meta($post->ID, self::PRODUCT_PERSONALIZABLE, true) === 'yes';
        $assigned = get_post_meta($post->ID, self::PRODUCT_BASE_MOCKUPS, true);
        $assigned = is_array($assigned) ? $assigned : [];
        echo '<p><label><input type="checkbox" name="belastock_personalizable" value="yes" '.checked($personalizable, true, false).'> Produto personalizável — exibir briefing na página do produto</label></p>';
        $mockups = get_posts(['post_type'=>'bs_mockup','post_status'=>'publish','numberposts'=>200,'orderby'=>'title','order'=>'ASC']);
        echo '<p><strong>Mockups base associados</strong> — imagens sem logo/estampa para referência interna.</p><table class="form-table"><tbody>';
        foreach (self::VIEWS as $key => $label) {
            echo '<tr><th>'.esc_html($label).'</th><td><select name="belastock_base_mockups['.esc_attr($key).']"><option value="0">Nenhum</option>';
            foreach ($mockups as $mockup) {
                echo '<option value="'.absint($mockup->ID).'" '.selected(absint($assigned[$key] ?? 0), $mockup->ID, false).'>'.esc_html($mockup->post_title).'</option>';
            }
            echo '</select></td></tr>';
        }
        echo '</tbody></table>';
    }

    public static function save_product(int $post_id, WP_Post $post): void {
        if (!isset($_POST['belastock_product_ops_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['belastock_product_ops_nonce'])), 'belastock_product_ops_save')) return;
        if (wp_is_post_revision($post_id) || !current_user_can('edit_post', $post_id)) return;
        update_post_meta($post_id, self::PRODUCT_PERSONALIZABLE, isset($_POST['belastock_personalizable']) ? 'yes' : 'no');
        $raw = isset($_POST['belastock_base_mockups']) ? (array)wp_unslash($_POST['belastock_base_mockups']) : [];
        $clean = [];
        foreach (array_keys(self::VIEWS) as $key) {
            $id = absint($raw[$key] ?? 0);
            $clean[$key] = $id && get_post_type($id) === 'bs_mockup' ? $id : 0;
        }
        update_post_meta($post_id, self::PRODUCT_BASE_MOCKUPS, $clean);
    }

    public static function mockup_columns(array $columns): array {
        return [
            'cb' => $columns['cb'] ?? '<input type="checkbox">',
            'thumbnail' => 'Imagem',
            'title' => 'Mockup',
            'bs_kind' => 'Produto',
            'bs_view' => 'Vista',
            'bs_color' => 'Cor',
            'date' => $columns['date'] ?? 'Data',
        ];
    }

    public static function mockup_column_content(string $column, int $post_id): void {
        if ($column === 'thumbnail') {
            echo get_the_post_thumbnail($post_id, [70,70]) ?: '<span style="color:#b32d2e">Sem imagem</span>';
        } elseif ($column === 'bs_kind') {
            $v = (string)get_post_meta($post_id, self::MOCKUP_KIND, true); echo esc_html(self::PRODUCT_KINDS[$v] ?? '—');
        } elseif ($column === 'bs_view') {
            $v = (string)get_post_meta($post_id, self::MOCKUP_VIEW, true); echo esc_html(self::VIEWS[$v] ?? '—');
        } elseif ($column === 'bs_color') {
            $v = (string)get_post_meta($post_id, self::MOCKUP_COLOR, true); echo esc_html(self::COLORS[$v] ?? '—');
        }
    }

    public static function admin_notices(): void {
        $key = 'belastock_mockup_notice_' . get_current_user_id();
        $message = get_transient($key);
        if ($message) {
            delete_transient($key);
            echo '<div class="notice notice-warning is-dismissible"><p>'.esc_html($message).'</p></div>';
        }
    }

    public static function render_personalization_field(): void {
        global $product;
        if (!$product instanceof WC_Product || get_post_meta($product->get_id(), self::PRODUCT_PERSONALIZABLE, true) !== 'yes') return;
        echo '<div class="belastock-personalization-brief" style="margin:16px 0"><label for="belastock_personalization_note"><strong>Briefing da personalização</strong></label><textarea id="belastock_personalization_note" name="belastock_personalization_note" rows="4" maxlength="500" placeholder="Descreva texto, posição, cores ou instruções. A arte final pode ser alinhada com a equipe antes da produção." style="width:100%;margin-top:8px"></textarea><small>Até 500 caracteres. A produção personalizada fica sujeita à validação dos detalhes do pedido.</small></div>';
    }

    public static function capture_personalization(array $cart_item_data, int $product_id, int $variation_id, int $quantity): array {
        if (get_post_meta($product_id, self::PRODUCT_PERSONALIZABLE, true) !== 'yes') return $cart_item_data;
        $note = sanitize_textarea_field(wp_unslash($_POST['belastock_personalization_note'] ?? ''));
        if ($note !== '') {
            $cart_item_data['belastock_personalization_note'] = mb_substr($note, 0, 500);
            $cart_item_data['belastock_personalization_key'] = wp_generate_uuid4();
        }
        return $cart_item_data;
    }

    public static function cart_item_data(array $item_data, array $cart_item): array {
        if (!empty($cart_item['belastock_personalization_note'])) {
            $item_data[] = ['key'=>'Personalização','value'=>wc_clean($cart_item['belastock_personalization_note'])];
        }
        return $item_data;
    }

    public static function order_line_meta(WC_Order_Item_Product $item, string $cart_item_key, array $values, WC_Order $order): void {
        if (!empty($values['belastock_personalization_note'])) $item->add_meta_data('Personalização', $values['belastock_personalization_note'], true);
    }

    public static function admin_menu(): void {
        add_submenu_page('woocommerce', 'Status Bela Stock', 'Status Bela Stock', 'manage_woocommerce', 'belastock-status', [__CLASS__, 'status_page']);
    }

    public static function status_page(): void {
        if (!current_user_can('manage_woocommerce')) return;
        if (!function_exists('is_plugin_active')) require_once ABSPATH . 'wp-admin/includes/plugin.php';
        $product_count = wp_count_posts('product');
        $mockup_count = wp_count_posts('bs_mockup');
        $required_categories = ['camisetas','manga-longa','regatas','baby-look','machao','moletons','bones','ecobags','adesivos','personalizados'];
        $missing_categories = array_values(array_filter($required_categories, static fn($slug) => !term_exists($slug, 'product_cat')));
        $attrs = array_map(static fn($a) => (string)$a->attribute_name, (array)wc_get_attribute_taxonomies());
        $missing_attrs = array_values(array_diff(['tamanho','cor','modelo'], $attrs));
        $plugins = [
            'Mercado Pago' => 'woocommerce-mercadopago/woocommerce-mercadopago.php',
            'PayPal' => 'woocommerce-paypal-payments/woocommerce-paypal-payments.php',
            'Melhor Envio' => 'melhor-envio-cotacao/melhor-envio-cotacao.php',
        ];
        echo '<div class="wrap"><h1>Status operacional — Bela Stock</h1><p>Esta tela verifica a estrutura da loja. Credenciais de pagamento e transportadora continuam dependendo da autorização das respectivas contas externas.</p><table class="widefat striped" style="max-width:980px"><tbody>';
        self::status_row('Produtos publicados', (int)($product_count->publish ?? 0) . ' publicados', true);
        self::status_row('Biblioteca de mockups', (int)($mockup_count->publish ?? 0) . ' publicados', true);
        self::status_row('Categorias', $missing_categories ? 'Faltando: '.implode(', ', $missing_categories) : 'Estrutura completa', !$missing_categories);
        self::status_row('Atributos', $missing_attrs ? 'Faltando: '.implode(', ', $missing_attrs) : 'Tamanho, Cor e Modelo', !$missing_attrs);
        foreach ($plugins as $label => $plugin) self::status_row($label, is_plugin_active($plugin) ? 'Plugin ativo — autorize/configure a conta externa para transações reais' : 'Plugin inativo', is_plugin_active($plugin));
        self::status_row('Checkout', wc_get_page_id('checkout') > 0 ? 'Página configurada' : 'Página ausente', wc_get_page_id('checkout') > 0);
        self::status_row('Minha Conta', wc_get_page_id('myaccount') > 0 ? 'Página configurada' : 'Página ausente', wc_get_page_id('myaccount') > 0);
        echo '</tbody></table><p><a class="button button-primary" href="'.esc_url(admin_url('edit.php?post_type=bs_mockup')).'">Abrir Biblioteca de Mockups</a> <a class="button" href="'.esc_url(admin_url('edit.php?post_type=product')).'">Abrir Produtos</a></p></div>';
    }

    private static function status_row(string $label, string $value, bool $ok): void {
        echo '<tr><th style="width:230px">'.esc_html($label).'</th><td><strong style="color:'.($ok ? '#167c3f' : '#b32d2e').'">'.($ok ? '✓ ' : '⚠ ').esc_html($value).'</strong></td></tr>';
    }
}

BelaStock_Operations::init();
