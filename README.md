# Bela Stock — Loja

Loja WooCommerce isolada para `loja.belastock.com.br`.

## Escopo
- WordPress + WooCommerce
- Camisetas, bonés e adesivos
- Tema próprio `belastock-store`
- Plugin próprio `belastock-core` para vistas de produto (frente, verso, lateral, detalhe e mockup)
- Mercado Pago, PayPal e Melhor Envio preparados
- Deploy por GitHub Actions em runner self-hosted

## Regra de segurança
Este repositório **não implanta nem altera o site principal Bela Stock**. O script aceita exclusivamente o domínio `loja.belastock.com.br` e o diretório dedicado `/home/belastock-loja/htdocs/loja.belastock.com.br`.

## Credenciais
Senhas e tokens não entram no Git. No primeiro deploy, credenciais locais são geradas no VPS e armazenadas com permissão `600` em `/root/.belastock-loja.env`.
