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
  <div class="bs-wrap">
    <a class="brand" href="<?php echo esc_url(home_url('/')); ?>">BELA <span>STOCK</span></a>
    <nav class="main-nav" aria-label="Navegação principal">
      <a href="<?php echo esc_url(home_url('/categoria-produto/camisetas/')); ?>">Camisetas</a>
      <a href="<?php echo esc_url(home_url('/categoria-produto/bones/')); ?>">Bonés</a>
      <a href="<?php echo esc_url(home_url('/categoria-produto/adesivos/')); ?>">Adesivos</a>
      <a href="<?php echo esc_url(home_url('/loja/')); ?>">Loja</a>
    </nav>
    <a class="header-cart" href="<?php echo esc_url(function_exists('wc_get_cart_url') ? wc_get_cart_url() : home_url('/carrinho/')); ?>">Carrinho (<?php echo esc_html((string) belastock_cart_count()); ?>)</a>
  </div>
</header>
