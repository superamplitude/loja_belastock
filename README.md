# Bela Stock — Loja

Loja WooCommerce isolada para `loja.belastock.com.br`.

## Escopo operacional
- WordPress + WooCommerce
- Catálogo: camisetas, manga longa, regatas, baby look, machão, moletons, bonés, ecobags, adesivos e personalizados
- Atributos globais: tamanho, cor e modelo
- Tema próprio `belastock-store`
- Bela Stock Core para fotos reais de produto e descontos progressivos
- Biblioteca de mockups-base administrável no painel, com tipo, vista e cor
- Briefing de personalização por produto
- Mercado Pago, PayPal e Melhor Envio instalados; transações reais dependem da autorização das contas externas
- Páginas operacionais: personalização, atacado, FAQ e rastreamento de pedido
- Deploy e auditoria por GitHub Actions em runner self-hosted

## Imagens
Mockups-base devem ser fotos reais sem logo e sem estampa, em JPG/JPEG ou WEBP e com pelo menos 1200 px no maior lado. A loja trabalha com imagens WooCommerce maiores e qualidade de compressão elevada para evitar perda desnecessária de definição.

## Regra de segurança
Este repositório não implanta nem altera o site principal Bela Stock. O deploy aceita exclusivamente `loja.belastock.com.br` no diretório `/home/belastock/htdocs/loja.belastock.com.br`.

## Credenciais
Senhas e tokens não entram no Git. Credenciais locais da instalação ficam no VPS e permissões/contas de Mercado Pago, PayPal e Melhor Envio devem ser autorizadas nos respectivos provedores.
