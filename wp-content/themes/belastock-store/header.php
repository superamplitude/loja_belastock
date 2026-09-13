<!doctype html>
<html <?php language_attributes(); ?>>
<head>
<meta charset="<?php bloginfo('charset'); ?>">
<meta name="viewport" content="width=device-width, initial-scale=1">
<?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
<header class="site-header">
<?php if (!function_exists('belastock_render_elementor_area') || !belastock_render_elementor_area('belastock_header_page_id')): ?>
  <div class="announcement-bar">Envio para todo o Brasil • Descontos progressivos por quantidade</div>
  <div class="bs-wrap header-main">
    <a class="brand brand-logo" href="<?php echo esc_url(home_url('/')); ?>"><img src="<?php echo esc_url(function_exists('belastock_logo_url') ? belastock_logo_url() : ''); ?>" alt="Bela Stock"></a>
    <nav class="main-nav" aria-label="Navegação principal">
      <a href="<?php echo esc_url(home_url('/categoria-produto/camisetas/')); ?>">Camisetas</a>
      <a href="<?php echo esc_url(home_url('/categoria-produto/bones/')); ?>">Bonés</a>
      <a href="<?php echo esc_url(home_url('/categoria-produto/adesivos/')); ?>">Adesivos</a>
      <a href="<?php echo esc_url(home_url('/loja/')); ?>">Loja</a>
      <a href="<?php echo esc_url(home_url('/minha-conta/')); ?>">Minha conta</a>
    </nav>
    <a class="header-cart" href="<?php echo esc_url(function_exists('wc_get_cart_url') ? wc_get_cart_url() : home_url('/carrinho/')); ?>">Carrinho (<?php echo esc_html((string) belastock_cart_count()); ?>)</a>
  </div>
<?php endif; ?>
</header>
