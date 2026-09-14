<?php get_header(); ?>
<main class="belastock-elementor-page">
<!-- BELASTOCK_VISUAL_V4 -->
<?php while (have_posts()): the_post(); ?>
    <?php the_content(); ?>
<?php endwhile; ?>

<section id="personalize" class="bs-v4-story" aria-labelledby="bs-personalize-title">
  <div class="bs-v4-story-grid">
    <div class="bs-v4-story-copy">
      <small>Bela Stock • personalização profissional</small>
      <h2 id="bs-personalize-title">Sua ideia, com acabamento de verdade.</h2>
      <p>Crie peças para uso pessoal, presentes, equipes, eventos e marcas. A Bela Stock combina produto, estampa e acabamento com uma apresentação mais limpa, segura e profissional.</p>
      <div class="bs-v4-story-actions">
        <a class="bs-v4-story-primary" href="<?php echo esc_url(home_url('/loja/')); ?>">Ver produtos</a>
        <a class="bs-v4-story-secondary" href="<?php echo esc_url(home_url('/contato/')); ?>">Falar com a Bela Stock</a>
      </div>
    </div>
    <div class="bs-v4-story-points">
      <div class="bs-v4-point"><b>Qualidade visual</b><span>Imagens maiores, cards consistentes e apresentação preparada para valorizar o produto.</span></div>
      <div class="bs-v4-point"><b>Personalização flexível</b><span>Camisetas, manga longa, regatas, baby look, bonés, ecobags e outros itens compatíveis.</span></div>
      <div class="bs-v4-point"><b>Desconto progressivo</b><span>Regras por quantidade aplicadas de forma automática no carrinho.</span></div>
      <div class="bs-v4-point"><b>Compra segura</b><span>Checkout, conta, entrega e pagamentos integrados ao WooCommerce.</span></div>
    </div>
  </div>
</section>
</main>
<?php get_footer(); ?>
