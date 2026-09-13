<?php
if (!defined('ABSPATH') || !class_exists('Elementor\\Widget_Base')) {
    return;
}

if (!class_exists('BelaStock_Elementor_Hero')) {
    class BelaStock_Elementor_Hero extends \Elementor\Widget_Base {
        public function get_name(): string { return 'belastock-hero'; }
        public function get_title(): string { return 'Bela Stock — Hero'; }
        public function get_icon(): string { return 'eicon-banner'; }
        public function get_categories(): array { return ['belastock']; }
        protected function register_controls(): void {
            $this->start_controls_section('content', ['label' => 'Conteúdo']);
            $this->add_control('eyebrow', ['label' => 'Linha superior', 'type' => \Elementor\Controls_Manager::TEXT, 'default' => 'Bela Stock • coleção autoral']);
            $this->add_control('title', ['label' => 'Título', 'type' => \Elementor\Controls_Manager::TEXTAREA, 'default' => 'Vista o que é seu.']);
            $this->add_control('text', ['label' => 'Texto', 'type' => \Elementor\Controls_Manager::TEXTAREA, 'default' => 'Camisetas, bonés e adesivos com identidade própria.']);
            $this->add_control('button_text', ['label' => 'Botão', 'type' => \Elementor\Controls_Manager::TEXT, 'default' => 'Ver a loja']);
            $this->add_control('button_link', ['label' => 'Link', 'type' => \Elementor\Controls_Manager::URL, 'default' => ['url' => home_url('/loja/')]]);
            $this->add_control('image', ['label' => 'Foto real do hero', 'type' => \Elementor\Controls_Manager::MEDIA, 'default' => ['url' => 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1800&q=88']]);
            $this->end_controls_section();
            $this->start_controls_section('style', ['label' => 'Estilo', 'tab' => \Elementor\Controls_Manager::TAB_STYLE]);
            $this->add_control('accent', ['label' => 'Cor do botão', 'type' => \Elementor\Controls_Manager::COLOR, 'default' => '#6f267e']);
            $this->add_control('background', ['label' => 'Fundo', 'type' => \Elementor\Controls_Manager::COLOR, 'default' => '#f5f2f6']);
            $this->end_controls_section();
        }
        protected function render(): void {
            $s = $this->get_settings_for_display();
            $url = !empty($s['image']['url']) ? $s['image']['url'] : '';
            $link = !empty($s['button_link']['url']) ? $s['button_link']['url'] : home_url('/loja/');
            echo '<section class="bs-el-hero" style="--bs-accent:'.esc_attr((string)$s['accent']).';--bs-bg:'.esc_attr((string)$s['background']).'">';
            echo '<div class="bs-el-hero-copy"><span>'.esc_html((string)$s['eyebrow']).'</span><h1>'.nl2br(esc_html((string)$s['title'])).'</h1><p>'.esc_html((string)$s['text']).'</p><a href="'.esc_url($link).'">'.esc_html((string)$s['button_text']).'</a></div>';
            echo '<div class="bs-el-hero-photo" style="background-image:url('.esc_url($url).')" role="img" aria-label="Foto real de modelo usando produto Bela Stock"></div>';
            echo '</section>';
        }
    }
}

if (!class_exists('BelaStock_Elementor_Announcement')) {
    class BelaStock_Elementor_Announcement extends \Elementor\Widget_Base {
        public function get_name(): string { return 'belastock-announcement'; }
        public function get_title(): string { return 'Bela Stock — Barra'; }
        public function get_icon(): string { return 'eicon-alert'; }
        public function get_categories(): array { return ['belastock']; }
        protected function register_controls(): void {
            $this->start_controls_section('content', ['label' => 'Barra']);
            $this->add_control('text', ['label' => 'Texto', 'type' => \Elementor\Controls_Manager::TEXT, 'default' => 'Envio para todo o Brasil • Descontos progressivos por quantidade']);
            $this->add_control('link', ['label' => 'Link opcional', 'type' => \Elementor\Controls_Manager::URL]);
            $this->add_control('bg', ['label' => 'Fundo', 'type' => \Elementor\Controls_Manager::COLOR, 'default' => '#4b1c57']);
            $this->add_control('color', ['label' => 'Texto', 'type' => \Elementor\Controls_Manager::COLOR, 'default' => '#ffffff']);
            $this->end_controls_section();
        }
        protected function render(): void {
            $s = $this->get_settings_for_display();
            $content = esc_html((string)$s['text']);
            if (!empty($s['link']['url'])) {
                $content = '<a href="'.esc_url($s['link']['url']).'">'.$content.'</a>';
            }
            echo '<div class="bs-el-announcement" style="background:'.esc_attr((string)$s['bg']).';color:'.esc_attr((string)$s['color']).'">'.$content.'</div>';
        }
    }
}

if (!class_exists('BelaStock_Elementor_Header')) {
    class BelaStock_Elementor_Header extends \Elementor\Widget_Base {
        public function get_name(): string { return 'belastock-header'; }
        public function get_title(): string { return 'Bela Stock — Cabeçalho'; }
        public function get_icon(): string { return 'eicon-header'; }
        public function get_categories(): array { return ['belastock']; }
        protected function register_controls(): void {
            $this->start_controls_section('content', ['label' => 'Cabeçalho']);
            $this->add_control('logo', ['label' => 'Logo', 'type' => \Elementor\Controls_Manager::MEDIA]);
            $this->add_control('show_categories', ['label' => 'Mostrar categorias', 'type' => \Elementor\Controls_Manager::SWITCHER, 'default' => 'yes']);
            $this->add_control('show_account', ['label' => 'Mostrar Minha Conta', 'type' => \Elementor\Controls_Manager::SWITCHER, 'default' => 'yes']);
            $this->end_controls_section();
        }
        protected function render(): void {
            $s = $this->get_settings_for_display();
            $fallback = get_theme_file_uri('/assets/belastock-logo.webp');
            $logo = !empty($s['logo']['url']) ? $s['logo']['url'] : $fallback;
            echo '<div class="bs-el-header"><a class="bs-el-logo" href="'.esc_url(home_url('/')).'"><img src="'.esc_url($logo).'" alt="Bela Stock"></a><nav>';
            if (($s['show_categories'] ?? 'yes') === 'yes') {
                echo '<a href="'.esc_url(home_url('/categoria-produto/camisetas/')).'">Camisetas</a><a href="'.esc_url(home_url('/categoria-produto/bones/')).'">Bonés</a><a href="'.esc_url(home_url('/categoria-produto/adesivos/')).'">Adesivos</a>';
            }
            echo '<a href="'.esc_url(home_url('/loja/')).'">Loja</a>';
            if (($s['show_account'] ?? 'yes') === 'yes') {
                echo '<a href="'.esc_url(home_url('/minha-conta/')).'">Minha conta</a>';
            }
            $count = function_exists('belastock_cart_count') ? belastock_cart_count() : 0;
            echo '</nav><a class="bs-el-cart" href="'.esc_url(function_exists('wc_get_cart_url') ? wc_get_cart_url() : home_url('/carrinho/')).'">Carrinho ('.absint($count).')</a></div>';
        }
    }
}

if (!class_exists('BelaStock_Elementor_Footer')) {
    class BelaStock_Elementor_Footer extends \Elementor\Widget_Base {
        public function get_name(): string { return 'belastock-footer'; }
        public function get_title(): string { return 'Bela Stock — Rodapé'; }
        public function get_icon(): string { return 'eicon-footer'; }
        public function get_categories(): array { return ['belastock']; }
        protected function register_controls(): void {
            $this->start_controls_section('content', ['label' => 'Rodapé']);
            $this->add_control('tagline', ['label' => 'Frase', 'type' => \Elementor\Controls_Manager::TEXT, 'default' => 'Vista-se bem e comunique-se melhor.']);
            $this->end_controls_section();
        }
        protected function render(): void {
            $s = $this->get_settings_for_display();
            $links = [
                'Sobre' => '/sobre-a-bela-stock/',
                'Entregas e frete' => '/entregas-e-frete/',
                'Trocas e devoluções' => '/trocas-e-devolucoes/',
                'Política de privacidade' => '/politica-de-privacidade/',
                'Termos e condições' => '/termos-e-condicoes/',
                'Contato' => '/contato/',
            ];
            echo '<div class="bs-el-footer"><div><img src="'.esc_url(get_theme_file_uri('/assets/belastock-logo.webp')).'" alt="Bela Stock"><p>'.esc_html((string)$s['tagline']).'</p></div><div><strong>Políticas e atendimento</strong><nav>';
            foreach ($links as $label => $path) {
                echo '<a href="'.esc_url(home_url($path)).'">'.esc_html($label).'</a>';
            }
            echo '</nav></div><div><strong>Compra</strong><nav><a href="'.esc_url(home_url('/loja/')).'">Loja</a><a href="'.esc_url(home_url('/carrinho/')).'">Carrinho</a><a href="'.esc_url(home_url('/finalizar-compra/')).'">Checkout</a><a href="'.esc_url(home_url('/minha-conta/')).'">Minha conta</a></nav></div></div>';
        }
    }
}

if (!class_exists('BelaStock_Elementor_Product')) {
    class BelaStock_Elementor_Product extends \Elementor\Widget_Base {
        public function get_name(): string { return 'belastock-product'; }
        public function get_title(): string { return 'Bela Stock — Produto Completo'; }
        public function get_icon(): string { return 'eicon-product-info'; }
        public function get_categories(): array { return ['belastock']; }
        protected function register_controls(): void {
            $this->start_controls_section('content', ['label' => 'Produto']);
            $this->add_control('show_gallery', ['label' => 'Galeria', 'type' => \Elementor\Controls_Manager::SWITCHER, 'default' => 'yes']);
            $this->add_control('show_description', ['label' => 'Descrição', 'type' => \Elementor\Controls_Manager::SWITCHER, 'default' => 'yes']);
            $this->add_control('show_mockups', ['label' => 'Fotos reais frente/verso', 'type' => \Elementor\Controls_Manager::SWITCHER, 'default' => 'yes']);
            $this->add_control('show_discounts', ['label' => 'Tabela de descontos', 'type' => \Elementor\Controls_Manager::SWITCHER, 'default' => 'yes']);
            $this->end_controls_section();
        }
        protected function render(): void {
            global $product;
            if (!$product instanceof WC_Product) {
                $product = wc_get_product(get_the_ID());
            }
            if (!$product instanceof WC_Product) {
                echo '<div class="woocommerce-info">Este widget deve ser usado em uma página de produto.</div>';
                return;
            }
            echo '<div class="bs-el-product">';
            if (($this->get_settings('show_gallery') ?? 'yes') === 'yes') {
                echo '<div class="bs-el-product-gallery">'.wp_kses_post($product->get_image('woocommerce_single'));
                foreach ($product->get_gallery_image_ids() as $id) {
                    echo wp_kses_post(wp_get_attachment_image($id, 'woocommerce_thumbnail'));
                }
                echo '</div>';
            }
            echo '<div class="bs-el-product-summary"><h1>'.esc_html($product->get_name()).'</h1><div class="price">'.$product->get_price_html().'</div>';
            if (($this->get_settings('show_description') ?? 'yes') === 'yes') {
                echo '<div class="bs-el-product-excerpt">'.wp_kses_post(wpautop($product->get_short_description())).'</div>';
            }
            woocommerce_template_single_add_to_cart();
            if (($this->get_settings('show_discounts') ?? 'yes') === 'yes') {
                echo wp_kses_post(BelaStock_Core::discount_table_html());
            }
            echo '</div></div>';
            if (($this->get_settings('show_mockups') ?? 'yes') === 'yes') {
                echo wp_kses_post(BelaStock_Core::render_real_views($product->get_id()));
            }
        }
    }
}
