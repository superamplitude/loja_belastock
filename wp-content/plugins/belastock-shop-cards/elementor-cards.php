<?php
if (!defined('ABSPATH') || !class_exists('Elementor\\Widget_Base')) {
    return;
}

if (!class_exists('BelaStock_Elementor_Product_Cards')) {
    class BelaStock_Elementor_Product_Cards extends \Elementor\Widget_Base {
        public function get_name(): string { return 'belastock-product-cards'; }
        public function get_title(): string { return 'Bela Stock — Cards de Produtos'; }
        public function get_icon(): string { return 'eicon-products'; }
        public function get_categories(): array { return ['belastock']; }
        protected function register_controls(): void {
            $this->start_controls_section('content', ['label' => 'Produtos']);
            $this->add_control('limit', ['label' => 'Quantidade', 'type' => \Elementor\Controls_Manager::NUMBER, 'default' => 8, 'min' => 1, 'max' => 24]);
            $this->add_control('columns', ['label' => 'Colunas', 'type' => \Elementor\Controls_Manager::SELECT, 'default' => '4', 'options' => ['1'=>'1','2'=>'2','3'=>'3','4'=>'4','5'=>'5','6'=>'6']]);
            $this->add_control('category', ['label' => 'Slug da categoria', 'type' => \Elementor\Controls_Manager::TEXT, 'placeholder' => 'camisetas']);
            $this->add_control('orderby', ['label' => 'Ordenar por', 'type' => \Elementor\Controls_Manager::SELECT, 'default' => 'date', 'options' => ['date'=>'Mais recentes','title'=>'Nome','price'=>'Preço','popularity'=>'Popularidade','rating'=>'Avaliação']]);
            $this->end_controls_section();
        }
        protected function render(): void {
            $s = $this->get_settings_for_display();
            echo BelaStock_Shop_Cards::render_product_cards([
                'limit' => absint($s['limit'] ?? 8),
                'columns' => absint($s['columns'] ?? 4),
                'category' => sanitize_title((string)($s['category'] ?? '')),
                'orderby' => sanitize_key((string)($s['orderby'] ?? 'date')),
                'order' => 'DESC',
            ]);
        }
    }
}

if (!class_exists('BelaStock_Elementor_Category_Cards')) {
    class BelaStock_Elementor_Category_Cards extends \Elementor\Widget_Base {
        public function get_name(): string { return 'belastock-category-cards'; }
        public function get_title(): string { return 'Bela Stock — Cards de Categorias'; }
        public function get_icon(): string { return 'eicon-gallery-grid'; }
        public function get_categories(): array { return ['belastock']; }
        protected function register_controls(): void {
            $this->start_controls_section('content', ['label' => 'Fotos reais']);
            $this->add_control('camisetas_image', ['label' => 'Camisetas', 'type' => \Elementor\Controls_Manager::MEDIA, 'default' => ['url' => 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=88']]);
            $this->add_control('bones_image', ['label' => 'Bonés', 'type' => \Elementor\Controls_Manager::MEDIA, 'default' => ['url' => 'https://images.unsplash.com/photo-1588850561407-ed78c282e89b?auto=format&fit=crop&w=1200&q=88']]);
            $this->add_control('adesivos_image', ['label' => 'Adesivos', 'type' => \Elementor\Controls_Manager::MEDIA, 'default' => ['url' => 'https://images.unsplash.com/photo-1572375992501-4b0892d50c69?auto=format&fit=crop&w=1200&q=88']]);
            $this->end_controls_section();
        }
        protected function render(): void {
            $s = $this->get_settings_for_display();
            echo BelaStock_Shop_Cards::render_category_cards([
                'camisetas_image' => $s['camisetas_image']['url'] ?? '',
                'bones_image' => $s['bones_image']['url'] ?? '',
                'adesivos_image' => $s['adesivos_image']['url'] ?? '',
            ]);
        }
    }
}
