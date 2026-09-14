<?php
if (!defined('ABSPATH')) exit;

/**
 * Bela Stock UI V4
 * Substitui os widgets de cabecalho/rodape por versoes mais completas,
 * mantendo tudo editavel via Elementor.
 */
add_action('elementor/widgets/register', static function ($widgets_manager): void {
    if (!class_exists('Elementor\\Widget_Base') || !class_exists('Elementor\\Controls_Manager')) return;

    foreach (['belastock-header','belastock-footer'] as $name) {
        if (method_exists($widgets_manager, 'unregister')) {
            $widgets_manager->unregister($name);
        } elseif (method_exists($widgets_manager, 'unregister_widget_type')) {
            $widgets_manager->unregister_widget_type($name);
        }
    }

    if (!class_exists('BelaStock_Elementor_Header_V4')) {
        class BelaStock_Elementor_Header_V4 extends \Elementor\Widget_Base {
            public function get_name(): string { return 'belastock-header'; }
            public function get_title(): string { return 'Bela Stock — Cabeçalho Pro'; }
            public function get_icon(): string { return 'eicon-header'; }
            public function get_categories(): array { return ['belastock']; }

            protected function register_controls(): void {
                $this->start_controls_section('content', ['label' => 'Cabecalho']);
                $this->add_control('logo', ['label'=>'Logo','type'=>\Elementor\Controls_Manager::MEDIA]);
                $this->add_control('search_placeholder', ['label'=>'Texto da busca','type'=>\Elementor\Controls_Manager::TEXT,'default'=>'O que você procura?']);
                $this->add_control('show_search', ['label'=>'Mostrar busca','type'=>\Elementor\Controls_Manager::SWITCHER,'default'=>'yes','return_value'=>'yes']);
                $this->add_control('show_categories', ['label'=>'Mostrar categorias','type'=>\Elementor\Controls_Manager::SWITCHER,'default'=>'yes','return_value'=>'yes']);
                $this->add_control('show_account', ['label'=>'Mostrar Minha conta','type'=>\Elementor\Controls_Manager::SWITCHER,'default'=>'yes','return_value'=>'yes']);
                $this->end_controls_section();
            }

            protected function render(): void {
                $s = $this->get_settings_for_display();
                $logo = !empty($s['logo']['url']) ? $s['logo']['url'] : get_theme_file_uri('/assets/belastock-logo.webp');
                $account = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('myaccount') : home_url('/minha-conta/');
                $cart = function_exists('wc_get_cart_url') ? wc_get_cart_url() : home_url('/carrinho/');
                $count = function_exists('belastock_cart_count') ? belastock_cart_count() : 0;

                echo '<div class="bs-v4-header">';
                echo '<div class="bs-v4-header-main">';
                echo '<a class="bs-v4-logo" href="'.esc_url(home_url('/')).'"><img src="'.esc_url($logo).'" alt="Bela Stock"></a>';
                if (($s['show_search'] ?? 'yes') === 'yes') {
                    echo '<form class="bs-v4-search" role="search" method="get" action="'.esc_url(home_url('/')).'">';
                    echo '<label class="screen-reader-text" for="bs-product-search">Buscar produtos</label>';
                    echo '<input id="bs-product-search" type="search" name="s" placeholder="'.esc_attr((string)($s['search_placeholder'] ?? 'O que você procura?')).'" value="'.esc_attr(get_search_query()).'">';
                    echo '<input type="hidden" name="post_type" value="product">';
                    echo '<button type="submit" aria-label="Buscar"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.7"></circle><path d="m16 16 4 4"></path></svg></button></form>';
                }
                echo '<div class="bs-v4-actions">';
                if (($s['show_account'] ?? 'yes') === 'yes') {
                    echo '<a class="bs-v4-action" href="'.esc_url($account).'" aria-label="Minha conta"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="3.4"></circle><path d="M5.5 20c.5-4 2.8-6 6.5-6s6 2 6.5 6"></path></svg><span>Minha conta</span></a>';
                }
                echo '<a class="bs-v4-action bs-v4-cart" href="'.esc_url($cart).'" aria-label="Carrinho"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h2l2.1 10.2h9.8l2-7.2H7"></path><circle cx="9" cy="19" r="1.4"></circle><circle cx="17" cy="19" r="1.4"></circle></svg><span>Carrinho</span><b>'.absint($count).'</b></a>';
                echo '</div></div>';

                echo '<nav class="bs-v4-nav" aria-label="Navegação principal"><div class="bs-v4-nav-inner">';
                echo '<a href="'.esc_url(home_url('/')).'">Início</a><a href="'.esc_url(home_url('/loja/')).'">Todos os produtos</a>';
                if (($s['show_categories'] ?? 'yes') === 'yes') {
                    $cats = [
                        'camisetas'=>'Camisetas','manga-longa'=>'Manga longa','regatas'=>'Regatas','baby-look'=>'Baby look',
                        'machao'=>'Machão','moletons'=>'Moletons','bones'=>'Bonés','ecobags'=>'Ecobags','adesivos'=>'Adesivos'
                    ];
                    foreach ($cats as $slug => $label) {
                        $term = get_term_by('slug', $slug, 'product_cat');
                        if ($term && !is_wp_error($term)) {
                            $url = get_term_link($term);
                            if (!is_wp_error($url)) echo '<a href="'.esc_url($url).'">'.esc_html($label).'</a>';
                        }
                    }
                }
                echo '<a class="bs-v4-nav-accent" href="'.esc_url(home_url('/#personalize')).'">Personalize</a>';
                echo '</div></nav></div>';
            }
        }
    }

    if (!class_exists('BelaStock_Elementor_Footer_V4')) {
        class BelaStock_Elementor_Footer_V4 extends \Elementor\Widget_Base {
            public function get_name(): string { return 'belastock-footer'; }
            public function get_title(): string { return 'Bela Stock — Rodapé Pro'; }
            public function get_icon(): string { return 'eicon-footer'; }
            public function get_categories(): array { return ['belastock']; }

            protected function register_controls(): void {
                $this->start_controls_section('content', ['label'=>'Rodape']);
                $this->add_control('tagline', ['label'=>'Frase','type'=>\Elementor\Controls_Manager::TEXTAREA,'default'=>'Vista-se bem e comunique-se melhor. Produtos com identidade, qualidade e personalidade.']);
                $this->add_control('email', ['label'=>'E-mail','type'=>\Elementor\Controls_Manager::TEXT,'default'=>'contato@belastock.com.br']);
                $this->end_controls_section();
            }

            protected function render(): void {
                $s = $this->get_settings_for_display();
                $logo = get_theme_file_uri('/assets/belastock-logo.webp');
                echo '<div class="bs-v4-footer"><div class="bs-v4-footer-grid">';
                echo '<div class="bs-v4-footer-brand"><img src="'.esc_url($logo).'" alt="Bela Stock"><p>'.esc_html((string)$s['tagline']).'</p><a href="mailto:'.esc_attr((string)$s['email']).'">'.esc_html((string)$s['email']).'</a></div>';
                echo '<div><strong>Loja</strong><nav><a href="'.esc_url(home_url('/loja/')).'">Todos os produtos</a><a href="'.esc_url(home_url('/categoria-produto/camisetas/')).'">Camisetas</a><a href="'.esc_url(home_url('/categoria-produto/bones/')).'">Bonés</a><a href="'.esc_url(home_url('/categoria-produto/ecobags/')).'">Ecobags</a></nav></div>';
                echo '<div><strong>Atendimento</strong><nav><a href="'.esc_url(home_url('/minha-conta/')).'">Minha conta</a><a href="'.esc_url(home_url('/entregas-e-frete/')).'">Entregas e frete</a><a href="'.esc_url(home_url('/trocas-e-devolucoes/')).'">Trocas e devoluções</a><a href="'.esc_url(home_url('/contato/')).'">Contato</a></nav></div>';
                echo '<div><strong>Políticas</strong><nav><a href="'.esc_url(home_url('/politica-de-privacidade/')).'">Privacidade</a><a href="'.esc_url(home_url('/termos-e-condicoes/')).'">Termos e condições</a><a href="'.esc_url(home_url('/sobre-a-bela-stock/')).'">Sobre a Bela Stock</a></nav></div>';
                echo '</div><div class="bs-v4-footer-bottom"><span>© '.esc_html(wp_date('Y')).' Bela Stock. Todos os direitos reservados.</span><span>Compra segura • PIX • cartões • entrega para todo o Brasil</span></div></div>';
            }
        }
    }

    $widgets_manager->register(new BelaStock_Elementor_Header_V4());
    $widgets_manager->register(new BelaStock_Elementor_Footer_V4());
}, 100);
