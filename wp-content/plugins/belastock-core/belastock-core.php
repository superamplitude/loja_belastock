<?php
/**
 * Plugin Name: Bela Stock Core
 * Description: Núcleo da loja Bela Stock: fotos reais frente/verso, descontos por quantidade e integração Elementor.
 * Version: 2.0.0
 * Author: Bela Stock
 * Requires Plugins: woocommerce
 */

if (!defined('ABSPATH')) {
    exit;
}

final class BelaStock_Core {
    private const META = '_belastock_real_views';
    private const OPTION_TIERS = 'belastock_quantity_discount_tiers';
    private const VERSION = '2.0.0';

    private const VIEWS = [
        'front_real'  => 'Foto real — Frente',
        'back_real'   => 'Foto real — Verso',
        'side_real'   => 'Foto real — Lateral',
        'detail_real' => 'Foto real — Detalhe',
    ];

    public static function init(): void {
        add_action('init', [__CLASS__, 'register_meta']);
        add_action('init', [__CLASS__, 'enable_elementor_products'], 20);
        add_action('add_meta_boxes', [__CLASS__, 'meta_box']);
        add_action('save_post_product', [__CLASS__, 'save'], 10, 2);
        add_action('admin_enqueue_scripts', [__CLASS__, 'admin_assets']);
        add_filter('manage_edit-product_columns', [__CLASS__, 'product_columns']);
        add_action('manage_product_posts_custom_column', [__CLASS__, 'product_column_content'], 10, 2);

        add_action('woocommerce_before_calculate_totals', [__CLASS__, 'apply_quantity_discount'], 20, 1);
        add_action('woocommerce_single_product_summary', [__CLASS__, 'render_discount_table'], 25);
        add_shortcode('belastock_quantity_discounts', [__CLASS__, 'discount_shortcode']);
        add_shortcode('belastock_real_mockups', [__CLASS__, 'mockup_shortcode']);

        add_action('admin_menu', [__CLASS__, 'discount_menu'], 90);
        add_action('admin_post_belastock_save_discounts', [__CLASS__, 'save_discount_settings']);

        add_action('elementor/elements/categories_registered', [__CLASS__, 'elementor_category']);
        add_action('elementor/widgets/register', [__CLASS__, 'register_elementor_widgets']);
        add_filter('wp_robots', [__CLASS__, 'hide_layout_pages_from_search']);
    }

    public static function activate(): void {
        if (get_option(self::OPTION_TIERS, null) === null) {
            update_option(self::OPTION_TIERS, self::default_tiers());
        }
        self::enable_elementor_products();
    }

    public static function default_tiers(): array {
        return [
            ['min' => 1, 'discount' => 0],
            ['min' => 2, 'discount' => 5],
            ['min' => 5, 'discount' => 10],
            ['min' => 10, 'discount' => 15],
            ['min' => 20, 'discount' => 20],
            ['min' => 50, 'discount' => 25],
        ];
    }

    public static function get_tiers(): array {
        $tiers = get_option(self::OPTION_TIERS, self::default_tiers());
        if (!is_array($tiers) || !$tiers) {
            return self::default_tiers();
        }
        usort($tiers, static fn($a, $b) => ((int)($a['min'] ?? 0)) <=> ((int)($b['min'] ?? 0)));
        return $tiers;
    }

    public static function register_meta(): void {
        register_post_meta('product', self::META, [
            'type' => 'object',
            'single' => true,
            'show_in_rest' => false,
            'sanitize_callback' => [__CLASS__, 'sanitize_views'],
            'auth_callback' => static fn() => current_user_can('edit_products'),
        ]);
    }

    public static function enable_elementor_products(): void {
        $types = get_option('elementor_cpt_support', ['page', 'post']);
        $types = is_array($types) ? $types : ['page', 'post'];
        if (!in_array('product', $types, true)) {
            $types[] = 'product';
            update_option('elementor_cpt_support', array_values(array_unique($types)));
        }
    }

    public static function sanitize_views($value): array {
        $value = is_array($value) ? $value : [];
        $clean = [];
        foreach (array_keys(self::VIEWS) as $key) {
            $id = isset($value[$key]) ? absint($value[$key]) : 0;
            $clean[$key] = self::is_real_photo_attachment($id) ? $id : 0;
        }
        return $clean;
    }

    private static function is_real_photo_attachment(int $id): bool {
        if (!$id) {
            return false;
        }
        $mime = (string) get_post_mime_type($id);
        return in_array($mime, ['image/jpeg', 'image/webp'], true);
    }

    public static function meta_box(): void {
        add_meta_box(
            'belastock-real-product-views',
            'Bela Stock — Fotos reais do produto',
            [__CLASS__, 'box_html'],
            'product',
            'normal',
            'high'
        );
    }

    public static function box_html(WP_Post $post): void {
        wp_nonce_field('belastock_views_save', 'belastock_views_nonce');
        $values = get_post_meta($post->ID, self::META, true);
        $values = is_array($values) ? $values : [];

        echo '<div class="belastock-photo-rule"><strong>REGRA DA LOJA:</strong> use somente fotografias reais do produto. Frente e verso devem ser fotos reais; ilustrações, desenhos, SVG e mockups desenhados não são aceitos. Formatos permitidos: JPG/JPEG e WEBP.</div>';
        echo '<div class="belastock-view-grid">';
        foreach (self::VIEWS as $key => $label) {
            $id = absint($values[$key] ?? 0);
            $src = $id ? wp_get_attachment_image_url($id, 'medium') : '';
            echo '<div class="belastock-view-card" data-view="'.esc_attr($key).'">';
            echo '<strong>' . esc_html($label) . '</strong>';
            if (in_array($key, ['front_real', 'back_real'], true)) {
                echo '<span class="belastock-required">Obrigatória para apresentação completa</span>';
            }
            echo '<div class="belastock-preview">' . ($src ? '<img src="'.esc_url($src).'" alt="">' : '<span>Sem foto real</span>') . '</div>';
            echo '<input type="hidden" name="belastock_real_views['.esc_attr($key).']" value="'.esc_attr($id).'">';
            echo '<button type="button" class="button button-primary belastock-pick">Selecionar foto real</button> ';
            echo '<button type="button" class="button-link-delete belastock-clear">Remover</button>';
            echo '</div>';
        }
        echo '</div>';
    }

    public static function admin_assets(string $hook): void {
        global $post_type;
        if ($post_type !== 'product' || !in_array($hook, ['post.php', 'post-new.php'], true)) {
            return;
        }
        wp_enqueue_media();
        wp_register_style('belastock-core-admin', false, [], self::VERSION);
        wp_enqueue_style('belastock-core-admin');
        wp_add_inline_style('belastock-core-admin', '.belastock-photo-rule{padding:14px 16px;border-left:4px solid #6f267e;background:#f8f1fb;margin:10px 0 18px;line-height:1.55}.belastock-view-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:16px}.belastock-view-card{border:1px solid #ddd;border-radius:12px;padding:14px;background:#fff}.belastock-required{display:block;color:#b32d2e;font-size:12px;margin-top:4px}.belastock-preview{height:170px;margin:12px 0;background:#f6f6f6;display:flex;align-items:center;justify-content:center;overflow:hidden;border-radius:9px}.belastock-preview img{width:100%;height:100%;object-fit:cover}');

        $script = <<<'JS'
jQuery(function($){
    $('.belastock-pick').on('click', function(){
        const card = $(this).closest('.belastock-view-card');
        const frame = wp.media({title:'Selecione uma FOTO REAL em JPG/JPEG ou WEBP',button:{text:'Usar foto real'},multiple:false,library:{type:'image'}});
        frame.on('select', function(){
            const attachment = frame.state().get('selection').first().toJSON();
            const mime = attachment.mime || '';
            if (mime !== 'image/jpeg' && mime !== 'image/webp') {
                window.alert('A Bela Stock aceita neste campo somente fotografia real em JPG/JPEG ou WEBP. PNG, SVG, ilustração e desenho não são aceitos.');
                return;
            }
            card.find('input[type="hidden"]').val(attachment.id);
            card.find('.belastock-preview').html('<img src="' + attachment.url + '" alt="">');
        });
        frame.open();
    });
    $('.belastock-clear').on('click', function(){
        const card = $(this).closest('.belastock-view-card');
        card.find('input[type="hidden"]').val('');
        card.find('.belastock-preview').html('<span>Sem foto real</span>');
    });
});
JS;
        wp_add_inline_script('jquery-core', $script);
    }

    public static function save(int $post_id, WP_Post $post): void {
        if (!isset($_POST['belastock_views_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['belastock_views_nonce'])), 'belastock_views_save')) {
            return;
        }
        if (!current_user_can('edit_post', $post_id) || wp_is_post_revision($post_id)) {
            return;
        }
        $raw = isset($_POST['belastock_real_views']) ? (array) wp_unslash($_POST['belastock_real_views']) : [];
        update_post_meta($post_id, self::META, self::sanitize_views($raw));
        self::seed_elementor_product($post_id);
    }


    public static function seed_elementor_product(int $post_id): void {
        if (get_post_type($post_id) !== 'product' || get_post_meta($post_id, '_elementor_data', true)) {
            return;
        }
        $data = [[
            'id' => 'bsprod01',
            'elType' => 'container',
            'settings' => ['content_width' => 'full'],
            'elements' => [[
                'id' => 'bsprod02',
                'elType' => 'widget',
                'widgetType' => 'belastock-product',
                'settings' => [],
                'elements' => [],
            ]],
        ]];
        update_post_meta($post_id, '_elementor_edit_mode', 'builder');
        update_post_meta($post_id, '_elementor_template_type', 'wp-post');
        update_post_meta($post_id, '_elementor_data', wp_slash(wp_json_encode($data)));
        if (defined('ELEMENTOR_VERSION')) {
            update_post_meta($post_id, '_elementor_version', ELEMENTOR_VERSION);
        }
    }

    public static function product_columns(array $columns): array {
        $columns['belastock_real_photos'] = 'Fotos reais';
        return $columns;
    }

    public static function product_column_content(string $column, int $post_id): void {
        if ($column !== 'belastock_real_photos') {
            return;
        }
        $views = get_post_meta($post_id, self::META, true);
        $views = is_array($views) ? $views : [];
        $front = absint($views['front_real'] ?? 0);
        $back = absint($views['back_real'] ?? 0);
        echo ($front && $back)
            ? '<span style="color:#167c3f;font-weight:700">✓ Frente + verso</span>'
            : '<span style="color:#b32d2e;font-weight:700">⚠ Incompleto</span>';
    }

    public static function render_real_views(?int $product_id = null): string {
        $product_id = $product_id ?: get_the_ID();
        $views = get_post_meta($product_id, self::META, true);
        if (!is_array($views)) {
            return '';
        }
        $items = [];
        foreach (self::VIEWS as $key => $label) {
            $id = absint($views[$key] ?? 0);
            if ($id && self::is_real_photo_attachment($id)) {
                $items[] = [$label, $id];
            }
        }
        if (!$items) {
            return '';
        }
        ob_start();
        echo '<section class="belastock-real-views"><h2>Fotos reais do produto</h2><div class="belastock-real-views-grid">';
        foreach ($items as [$label, $id]) {
            $full = wp_get_attachment_image_url($id, 'full');
            echo '<figure><a href="'.esc_url((string)$full).'">'.wp_get_attachment_image($id, 'large').'</a><figcaption>'.esc_html($label).'</figcaption></figure>';
        }
        echo '</div></section>';
        return (string) ob_get_clean();
    }

    public static function mockup_shortcode(array $atts = []): string {
        $atts = shortcode_atts(['id' => 0], $atts, 'belastock_real_mockups');
        return self::render_real_views(absint($atts['id']) ?: get_the_ID());
    }

    private static function discount_for_quantity(int $qty): float {
        $discount = 0.0;
        foreach (self::get_tiers() as $tier) {
            $min = max(1, absint($tier['min'] ?? 1));
            $pct = min(90, max(0, (float)($tier['discount'] ?? 0)));
            if ($qty >= $min) {
                $discount = $pct;
            }
        }
        return $discount;
    }

    public static function apply_quantity_discount(WC_Cart $cart): void {
        if (is_admin() && !defined('DOING_AJAX')) {
            return;
        }
        if (did_action('woocommerce_before_calculate_totals') >= 4) {
            return;
        }
        foreach ($cart->get_cart() as $key => $cart_item) {
            if (empty($cart_item['data']) || !($cart_item['data'] instanceof WC_Product)) {
                continue;
            }
            $product = $cart_item['data'];
            $qty = max(1, (int)($cart_item['quantity'] ?? 1));
            if (!isset($cart->cart_contents[$key]['belastock_base_price'])) {
                $cart->cart_contents[$key]['belastock_base_price'] = (float) $product->get_price('edit');
            }
            $base = (float) $cart->cart_contents[$key]['belastock_base_price'];
            $pct = self::discount_for_quantity($qty);
            $product->set_price(wc_format_decimal($base * (1 - ($pct / 100))));
            $cart->cart_contents[$key]['belastock_discount_pct'] = $pct;
        }
    }

    public static function discount_table_html(): string {
        $tiers = self::get_tiers();
        if (!$tiers) {
            return '';
        }
        ob_start();
        echo '<div class="belastock-discount-box"><strong>Desconto progressivo por quantidade</strong><table><thead><tr><th>Quantidade</th><th>Desconto</th></tr></thead><tbody>';
        $count = count($tiers);
        foreach ($tiers as $i => $tier) {
            $min = max(1, absint($tier['min'] ?? 1));
            $pct = min(90, max(0, (float)($tier['discount'] ?? 0)));
            $next = $i + 1 < $count ? max($min, absint($tiers[$i + 1]['min'] ?? 0) - 1) : null;
            $label = $next ? $min . ' a ' . $next : $min . '+';
            echo '<tr><td>'.esc_html($label).'</td><td>'.esc_html(wc_format_localized_decimal($pct)).'%</td></tr>';
        }
        echo '</tbody></table><small>O desconto é aplicado automaticamente à quantidade de cada produto no carrinho.</small></div>';
        return (string) ob_get_clean();
    }

    public static function render_discount_table(): void {
        echo wp_kses_post(self::discount_table_html());
    }

    public static function discount_shortcode(): string {
        return self::discount_table_html();
    }

    public static function discount_menu(): void {
        add_submenu_page('woocommerce', 'Descontos Bela Stock', 'Descontos Bela Stock', 'manage_woocommerce', 'belastock-discounts', [__CLASS__, 'discount_settings_page']);
    }

    public static function discount_settings_page(): void {
        if (!current_user_can('manage_woocommerce')) {
            return;
        }
        $tiers = self::get_tiers();
        echo '<div class="wrap"><h1>Descontos por quantidade — Bela Stock</h1><p>Defina as faixas globais. A maior faixa atingida é aplicada automaticamente a cada item do carrinho.</p>';
        echo '<form method="post" action="'.esc_url(admin_url('admin-post.php')).'">';
        wp_nonce_field('belastock_save_discounts');
        echo '<input type="hidden" name="action" value="belastock_save_discounts"><table class="widefat striped" style="max-width:720px"><thead><tr><th>Quantidade mínima</th><th>Desconto (%)</th></tr></thead><tbody>';
        for ($i = 0; $i < 8; $i++) {
            $tier = $tiers[$i] ?? ['min' => '', 'discount' => ''];
            echo '<tr><td><input type="number" min="1" name="tiers['.$i.'][min]" value="'.esc_attr((string)$tier['min']).'"></td><td><input type="number" min="0" max="90" step="0.01" name="tiers['.$i.'][discount]" value="'.esc_attr((string)$tier['discount']).'"></td></tr>';
        }
        echo '</tbody></table><p><button class="button button-primary">Salvar descontos</button></p></form></div>';
    }

    public static function save_discount_settings(): void {
        if (!current_user_can('manage_woocommerce')) {
            wp_die('Sem permissão.');
        }
        check_admin_referer('belastock_save_discounts');
        $raw = isset($_POST['tiers']) ? (array) wp_unslash($_POST['tiers']) : [];
        $tiers = [];
        foreach ($raw as $row) {
            $min = absint($row['min'] ?? 0);
            if ($min < 1) {
                continue;
            }
            $tiers[] = ['min' => $min, 'discount' => min(90, max(0, (float)($row['discount'] ?? 0)))];
        }
        if (!$tiers) {
            $tiers = self::default_tiers();
        }
        usort($tiers, static fn($a, $b) => $a['min'] <=> $b['min']);
        update_option(self::OPTION_TIERS, $tiers);
        wp_safe_redirect(admin_url('admin.php?page=belastock-discounts&updated=1'));
        exit;
    }

    public static function elementor_category($elements_manager): void {
        $elements_manager->add_category('belastock', ['title' => 'Bela Stock', 'icon' => 'fa fa-shopping-bag']);
    }

    public static function register_elementor_widgets($widgets_manager): void {
        if (!class_exists('Elementor\\Widget_Base')) {
            return;
        }
        require_once __DIR__ . '/elementor-widgets.php';
        foreach (['BelaStock_Elementor_Hero', 'BelaStock_Elementor_Announcement', 'BelaStock_Elementor_Header', 'BelaStock_Elementor_Footer', 'BelaStock_Elementor_Product'] as $class) {
            if (class_exists($class)) {
                $widgets_manager->register(new $class());
            }
        }
    }

    public static function hide_layout_pages_from_search(array $robots): array {
        $ids = array_filter([absint(get_option('belastock_header_page_id')), absint(get_option('belastock_footer_page_id'))]);
        if ($ids && is_page($ids)) {
            $robots['noindex'] = true;
            $robots['nofollow'] = true;
        }
        return $robots;
    }
}

register_activation_hook(__FILE__, ['BelaStock_Core', 'activate']);
BelaStock_Core::init();
