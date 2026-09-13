<?php
/**
 * Plugin Name: Bela Stock Core
 * Description: Campos e visualização de frente, verso, lateral, detalhe e mockup para produtos WooCommerce.
 * Version: 1.0.0
 * Author: Bela Stock
 */

if (!defined('ABSPATH')) exit;

final class BelaStock_Core {
    private const META = '_belastock_product_views';
    private const VIEWS = [
        'front'  => 'Frente',
        'back'   => 'Verso',
        'side'   => 'Lateral',
        'detail' => 'Detalhe',
        'mockup' => 'Mockup real',
    ];

    public static function init(): void {
        add_action('add_meta_boxes', [__CLASS__, 'meta_box']);
        add_action('save_post_product', [__CLASS__, 'save'], 10, 2);
        add_action('admin_enqueue_scripts', [__CLASS__, 'admin_assets']);
        add_action('woocommerce_after_single_product_summary', [__CLASS__, 'render_views'], 8);
        add_action('init', [__CLASS__, 'register_meta']);
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

    public static function sanitize_views($value): array {
        $clean = [];
        foreach (array_keys(self::VIEWS) as $key) {
            $clean[$key] = isset($value[$key]) ? absint($value[$key]) : 0;
        }
        return $clean;
    }

    public static function meta_box(): void {
        add_meta_box('belastock-product-views', 'Bela Stock — vistas e mockups', [__CLASS__, 'box_html'], 'product', 'normal', 'high');
    }

    public static function box_html(WP_Post $post): void {
        wp_nonce_field('belastock_views_save', 'belastock_views_nonce');
        $values = get_post_meta($post->ID, self::META, true);
        $values = is_array($values) ? $values : [];
        echo '<p>Adicione imagens independentes para frente, verso, lateral, detalhe e mockup real. Elas aparecem identificadas na página do produto.</p>';
        echo '<div class="belastock-view-grid">';
        foreach (self::VIEWS as $key => $label) {
            $id = absint($values[$key] ?? 0);
            $src = $id ? wp_get_attachment_image_url($id, 'medium') : '';
            echo '<div class="belastock-view-card">';
            echo '<strong>' . esc_html($label) . '</strong>';
            echo '<div class="belastock-preview">' . ($src ? '<img src="'.esc_url($src).'" alt="">' : '<span>Sem imagem</span>') . '</div>';
            echo '<input type="hidden" name="belastock_views['.esc_attr($key).']" value="'.esc_attr($id).'">';
            echo '<button type="button" class="button belastock-pick">Selecionar imagem</button> ';
            echo '<button type="button" class="button-link-delete belastock-clear">Remover</button>';
            echo '</div>';
        }
        echo '</div>';
    }

    public static function admin_assets(string $hook): void {
        global $post_type;
        if ($post_type !== 'product' || !in_array($hook, ['post.php','post-new.php'], true)) return;
        wp_enqueue_media();
        wp_add_inline_style('wp-admin', '.belastock-view-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:16px}.belastock-view-card{border:1px solid #ddd;border-radius:10px;padding:12px;background:#fff}.belastock-preview{height:150px;margin:10px 0;background:#f6f6f6;display:flex;align-items:center;justify-content:center;overflow:hidden}.belastock-preview img{width:100%;height:100%;object-fit:cover}');
        wp_add_inline_script('jquery-core', "jQuery(function($){$('.belastock-pick').on('click',function(){const c=$(this).closest('.belastock-view-card');const f=wp.media({title:'Selecionar imagem',button:{text:'Usar imagem'},multiple:false});f.on('select',function(){const a=f.state().get('selection').first().toJSON();c.find('input[type=hidden]').val(a.id);c.find('.belastock-preview').html('<img src=\"'+a.url+'\" alt=\"\">');});f.open();});$('.belastock-clear').on('click',function(){const c=$(this).closest('.belastock-view-card');c.find('input[type=hidden]').val('');c.find('.belastock-preview').html('<span>Sem imagem</span>');});});");
    }

    public static function save(int $post_id, WP_Post $post): void {
        if (!isset($_POST['belastock_views_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['belastock_views_nonce'])), 'belastock_views_save')) return;
        if (!current_user_can('edit_post', $post_id) || wp_is_post_revision($post_id)) return;
        $raw = isset($_POST['belastock_views']) ? (array) wp_unslash($_POST['belastock_views']) : [];
        update_post_meta($post_id, self::META, self::sanitize_views($raw));
    }

    public static function render_views(): void {
        if (!is_product()) return;
        global $product;
        if (!$product) return;
        $views = get_post_meta($product->get_id(), self::META, true);
        if (!is_array($views)) return;
        $items = [];
        foreach (self::VIEWS as $key => $label) {
            $id = absint($views[$key] ?? 0);
            if ($id) $items[] = [$label, $id];
        }
        if (!$items) return;
        echo '<section class="belastock-views"><h2>Veja todos os ângulos</h2><div class="belastock-views-grid">';
        foreach ($items as [$label,$id]) {
            echo '<figure><a href="'.esc_url(wp_get_attachment_image_url($id,'full')).'">'.wp_get_attachment_image($id,'large').'</a><figcaption>'.esc_html($label).'</figcaption></figure>';
        }
        echo '</div></section>';
    }
}
BelaStock_Core::init();
