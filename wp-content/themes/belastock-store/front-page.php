<?php get_header(); ?>
<main>
<section class="hero">
  <div class="hero-copy"><div class="hero-copy-inner">
    <span class="eyebrow">Bela Stock • coleção autoral</span>
    <h1>Vista<br>o que<br>é seu.</h1>
    <p>Camisetas, bonés e adesivos para quem prefere personalidade a uniforme. Produção cuidada, peças selecionadas e envio para todo o Brasil.</p>
    <a class="btn btn-accent" href="<?php echo esc_url(home_url('/loja/')); ?>">Ver a loja</a>
  </div></div>
  <div class="hero-media" role="img" aria-label="Modelo feminina vestindo camiseta preta"></div>
</section>

<section class="section"><div class="bs-wrap">
  <div class="section-title"><div><span class="eyebrow">Escolha seu estilo</span><h2>Feito para usar.</h2></div><p>Cadastre cada produto com foto principal, frente, verso, lateral, detalhes e mockup real diretamente no painel do WooCommerce.</p></div>
  <div class="category-grid">
    <a class="category-card" href="<?php echo esc_url(home_url('/categoria-produto/camisetas/')); ?>"><img src="https://images.unsplash.com/photo-1496360784265-52a2509684f3?auto=format&fit=crop&w=1000&q=82" alt="Camiseta"><div class="content"><h3>Camisetas</h3><p>Frente, verso, cores e tamanhos.</p></div></a>
    <a class="category-card" href="<?php echo esc_url(home_url('/categoria-produto/bones/')); ?>"><img src="https://images.unsplash.com/photo-1606483956061-46a898dce538?auto=format&fit=crop&w=1000&q=82" alt="Boné"><div class="content"><h3>Bonés</h3><p>Frente, lateral e traseira.</p></div></a>
    <a class="category-card" href="<?php echo esc_url(home_url('/categoria-produto/adesivos/')); ?>"><img src="https://images.unsplash.com/photo-1664289192124-f0d784151d11?auto=format&fit=crop&w=1000&q=82" alt="Adesivos"><div class="content"><h3>Adesivos</h3><p>Unidades, kits e coleções.</p></div></a>
  </div>
</div></section>

<?php if (class_exists('WooCommerce')): ?>
<section class="section"><div class="bs-wrap">
  <div class="section-title"><div><span class="eyebrow">Catálogo</span><h2>Lançamentos.</h2></div><a class="btn" href="<?php echo esc_url(home_url('/loja/')); ?>">Ver tudo</a></div>
  <?php echo do_shortcode('[products limit="8" columns="4" orderby="date" order="DESC" visibility="visible"]'); ?>
</div></section>
<?php endif; ?>

<section class="section"><div class="bs-wrap benefits">
  <div class="benefit"><strong>Pagamento seguro</strong><span>WooCommerce preparado para Mercado Pago e PayPal.</span></div>
  <div class="benefit"><strong>Frete calculado</strong><span>Integração preparada para Correios e transportadoras via Melhor Envio.</span></div>
  <div class="benefit"><strong>Produto por todos os lados</strong><span>Frente, verso, lateral, detalhes e mockups reais em cada cadastro.</span></div>
</div></section>
</main>
<?php get_footer(); ?>
