<?php
/**
 * Plugin Name: Bela Stock Shop Cards
 * Description: Cards de produtos e categorias para WooCommerce e Elementor, com layout próprio da Bela Stock.
 * Version: 1.0.0
 * Author: Bela Stock
 * Requires Plugins: woocommerce
 */

if (!defined('ABSPATH')) {
    exit;
}

final class BelaStock_Shop_Cards {
    private const VERSION = '1.0.0';

    public static function init(): void {
        add_action('wp_enqueue_scripts', [__CLASS__, 'assets']);
        add_shortcode('belastock_product_cards', [__CLASS__, 'product_cards_shortcode']);
        add_shortcode('belastock_category_cards', [__CLASS__, 'category_cards_shortcode']);
        add_action('elementor/widgets/register', [__CLASS__, 'register_elementor_widgets']);
        add_filter('woocommerce_loop_add_to_cart_link', [__CLASS__, 'loop_button'], 20, 3);
        add_action('woocommerce_before_shop_loop_item_title', [__CLASS__, 'category_badge'], 5);
    }

    public static function assets(): void {
        wp_register_style('belastock-shop-cards', false, [], self::VERSION);
        wp_enqueue_style('belastock-shop-cards');
        wp_add_inline_style('belastock-shop-cards', self::css());
    }

    private static function css(): string {
        return '
        .bs-product-cards{display:grid;gap:22px;grid-template-columns:repeat(var(--bs-cols,4),minmax(0,1fr))}
        .bs-product-card{background:#fff;border:1px solid #ece8ee;border-radius:20px;overflow:hidden;display:flex;flex-direction:column;min-width:0;box-shadow:0 10px 28px rgba(29,18,32,.06);transition:transform .2s ease,box-shadow .2s ease}
        .bs-product-card:hover{transform:translateY(-3px);box-shadow:0 18px 38px rgba(29,18,32,.10)}
        .bs-product-card-media{position:relative;background:#f5f3f5;aspect-ratio:1/1.12;overflow:hidden}
        .bs-product-card-media img{width:100%;height:100%;object-fit:cover;display:block}
        .bs-product-card-badge{position:absolute;left:12px;top:12px;background:#4b1c57;color:#fff;border-radius:999px;padding:7px 10px;font-size:12px;font-weight:800;letter-spacing:.02em}
        .bs-product-card-body{padding:16px;display:flex;flex-direction:column;gap:9px;flex:1}
        .bs-product-card-category{font-size:12px;text-transform:uppercase;letter-spacing:.08em;color:#7d7181;font-weight:800}
        .bs-product-card-title{font-size:18px;line-height:1.2;margin:0;color:#1a171c}
        .bs-product-card-price{font-size:18px;font-weight:900;color:#4b1c57}
        .bs-product-card-actions{margin-top:auto;display:flex;gap:8px;flex-wrap:wrap}
        .bs-product-card-actions a{display:inline-flex;align-items:center;justify-content:center;min-height:42px;padding:0 15px;border-radius:999px;background:#171319;color:#fff!important;font-weight:800;text-decoration:none}
        .bs-product-card-actions a.bs-card-secondary{background:#f1edf2;color:#4b1c57!important}
        .bs-category-cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}
        .bs-category-card{position:relative;min-height:390px;border-radius:22px;overflow:hidden;background:#ddd;color:#fff!important;text-decoration:none}
        .bs-category-card img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
        .bs-category-card:after{content:"";position:absolute;inset:0;background:linear-gradient(0deg,rgba(22,10,25,.82),rgba(22,10,25,.08) 64%)}
        .bs-category-card-content{position:absolute;z-index:2;left:22px;right:22px;bottom:22px}
        .bs-category-card h3{margin:0 0 6px;font-size:31px;line-height:1}
        .bs-category-card p{margin:0;color:#f4ecf5}
        .woocommerce ul.products li.product{position:relative}
        .bs-loop-category-badge{position:absolute;z-index:4;left:12px;top:12px;background:#4b1c57;color:#fff;border-radius:999px;padding:6px 9px;font-size:11px;font-weight:800}
        @media(max-width:980px){.bs-product-cards{grid-template-columns:repeat(2,minmax(0,1fr))}.bs-category-cards{grid-template-columns:1fr 1fr}}
        @media(max-width:620px){.bs-product-cards,.bs-category-cards{grid-template-columns:1fr}.bs-category-card{min-height:330px}}
        ';
    }

    public static function product_cards_shortcode(array $atts = []): string {
        $atts = shortcode_atts([
            'limit' => 8,
            'columns' => 4,
            'category' => '',
            'orderby' => 'date',
            'order' => 'DESC',
        ], $atts, 'belastock_product_cards');
        return self::render_product_cards($atts);
    }

    public static function render_product_cards(array $args = []): string {
        if (!function_exists('wc_get_products')) {
            return '';
        }
        $limit = min(24, max(1, absint($args['limit'] ?? 8)));
        $columns = min(6, max(1, absint($args['columns'] ?? 4)));
        $query = [
            'status' => 'publish',
            'limit' => $limit,
            'orderby' => sanitize_key($args['orderby'] ?? 'date'),
            'order' => strtoupper((string)($args['order'] ?? 'DESC')) === 'ASC' ? 'ASC' : 'DESC',
            'visibility' => 'visible',
        ];
        $category = sanitize_title((string)($args['category'] ?? ''));
        if ($category) {
            $query['category'] = [$category];
        }
        $products = wc_get_products($query);
        if (!$products) {
            return '<div class="woocommerce-info">Nenhum produto publicado nesta seleção.</div>';
        }
        ob_start();
        echo '<div class="bs-product-cards" style="--bs-cols:'.esc_attr((string)$columns).'">';
        foreach ($products as $product) {
            if (!$product instanceof WC_Product) {
                continue;
            }
            $id = $product->get_id();
            $permalink = get_permalink($id);
            $terms = get_the_terms($id, 'product_cat');
            $cat = ($terms && !is_wp_error($terms)) ? $terms[0]->name : 'Bela Stock';
            $image = $product->get_image('woocommerce_thumbnail', ['loading' => 'lazy']);
            echo '<article class="bs-product-card">';
            echo '<a class="bs-product-card-media" href="'.esc_url($permalink).'">'.$image.'<span class="bs-product-card-badge">Foto real no produto</span></a>';
            echo '<div class="bs-product-card-body"><span class="bs-product-card-category">'.esc_html($cat).'</span><h3 class="bs-product-card-title"><a href="'.esc_url($permalink).'">'.esc_html($product->get_name()).'</a></h3><div class="bs-product-card-price">'.$product->get_price_html().'</div>';
            echo '<div class="bs-product-card-actions"><a href="'.esc_url($permalink).'">Ver produto</a>';
            if ($product->is_purchasable() && $product->is_in_stock() && $product->is_type('simple')) {
                echo '<a class="bs-card-secondary add_to_cart_button ajax_add_to_cart" data-product_id="'.esc_attr((string)$id).'" data-quantity="1" href="'.esc_url($product->add_to_cart_url()).'">Adicionar</a>';
            }
            echo '</div></div></article>';
        }
        echo '</div>';
        return (string) ob_get_clean();
    }

    public static function category_cards_shortcode(array $atts = []): string {
        return self::render_category_cards($atts);
    }

    public static function render_category_cards(array $settings = []): string {
        $defaults = [
            'camisetas_image' => 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=88',
            'bones_image' => 'https://images.unsplash.com/photo-1588850561407-ed78c282e89b?auto=format&fit=crop&w=1200&q=88',
            'adesivos_image' => 'https://images.unsplash.com/photo-1572375992501-4b0892d50c69?auto=format&fit=crop&w=1200&q=88',
        ];
        $settings = wp_parse_args($settings, $defaults);
        $cards = [
            ['Camisetas', 'camisetas', 'Fotos reais de frente e verso, cores e tamanhos.', $settings['camisetas_image']],
            ['Bonés', 'bones', 'Fotos reais, detalhes do fechamento e acabamento.', $settings['bones_image']],
            ['Adesivos', 'adesivos', 'Unidades, kits e coleções com acabamento real.', $settings['adesivos_image']],
        ];
        ob_start();
        echo '<div class="bs-category-cards">';
        foreach ($cards as [$title, $slug, $text, $image]) {
            echo '<a class="bs-category-card" href="'.esc_url(home_url('/categoria-produto/'.$slug.'/')).'"><img src="'.esc_url($image).'" alt="'.esc_attr($title).'" loading="lazy"><div class="bs-category-card-content"><h3>'.esc_html($title).'</h3><p>'.esc_html($text).'</p></div></a>';
        }
        echo '</div>';
        return (string) ob_get_clean();
    }

    public static function loop_button(string $html, WC_Product $product, array $args): string {
        if ($product->is_type('variable')) {
            return '<a class="button" href="'.esc_url($product->get_permalink()).'">Escolher opções</a>';
        }
        return $html;
    }

    public static function category_badge(): void {
        global $product;
        if (!$product instanceof WC_Product) {
            return;
        }
        $terms = get_the_terms($product->get_id(), 'product_cat');
        if ($terms && !is_wp_error($terms)) {
            echo '<span class="bs-loop-category-badge">'.esc_html($terms[0]->name).'</span>';
        }
    }

    public static function register_elementor_widgets($widgets_manager): void {
        if (!class_exists('Elementor\\Widget_Base')) {
            return;
        }
        require_once __DIR__ . '/elementor-cards.php';
        foreach (['BelaStock_Elementor_Product_Cards', 'BelaStock_Elementor_Category_Cards'] as $class) {
            if (class_exists($class)) {
                $widgets_manager->register(new $class());
            }
        }
    }
}

BelaStock_Shop_Cards::init();
