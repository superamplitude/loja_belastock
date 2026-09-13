<footer class="site-footer">
<?php if (!function_exists('belastock_render_elementor_area') || !belastock_render_elementor_area('belastock_footer_page_id')): ?>
  <div class="bs-wrap footer-grid">
    <div><a class="footer-logo" href="<?php echo esc_url(home_url('/')); ?>"><img src="<?php echo esc_url(function_exists('belastock_logo_url') ? belastock_logo_url() : ''); ?>" alt="Bela Stock"></a><p>Vista-se bem e comunique-se melhor.</p></div>
    <div><strong>Compra</strong><nav><a href="<?php echo esc_url(home_url('/loja/')); ?>">Loja</a><a href="<?php echo esc_url(home_url('/carrinho/')); ?>">Carrinho</a><a href="<?php echo esc_url(home_url('/finalizar-compra/')); ?>">Checkout</a><a href="<?php echo esc_url(home_url('/minha-conta/')); ?>">Minha conta</a></nav></div>
    <div><strong>Políticas e atendimento</strong><nav><a href="<?php echo esc_url(home_url('/sobre-a-bela-stock/')); ?>">Sobre</a><a href="<?php echo esc_url(home_url('/entregas-e-frete/')); ?>">Entregas e frete</a><a href="<?php echo esc_url(home_url('/trocas-e-devolucoes/')); ?>">Trocas e devoluções</a><a href="<?php echo esc_url(home_url('/politica-de-privacidade/')); ?>">Política de privacidade</a><a href="<?php echo esc_url(home_url('/termos-e-condicoes/')); ?>">Termos e condições</a><a href="<?php echo esc_url(home_url('/contato/')); ?>">Contato</a></nav></div>
  </div>
  <div class="bs-wrap footer-bottom"><small>© <?php echo esc_html(wp_date('Y')); ?> Bela Stock. Todos os direitos reservados.</small></div>
<?php endif; ?>
</footer>
<?php wp_footer(); ?>
</body></html>
