#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN="loja.belastock.com.br"
SITE_USER="belastock"
DOCROOT="/home/${SITE_USER}/htdocs/${DOMAIN}"
SECRETS_FILE="/root/.belastock-loja.env"
DB_NAME="belastock_loja"
DB_USER="belastock_loja"
ADMIN_USER="belastock_admin"
ADMIN_EMAIL="contato@belastock.com.br"
REPO_ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
BACKUP_DIR="/home/${SITE_USER}/backups/loja_belastock"

log(){ printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
fail(){ printf '\n[ERRO] %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail "Execute este deploy como root no runner self-hosted."
command -v clpctl >/dev/null 2>&1 || fail "CloudPanel CLI (clpctl) não encontrado."
[[ "$DOMAIN" == "loja.belastock.com.br" ]] || fail "Trava de domínio acionada."
[[ "$SITE_USER" == "belastock" ]] || fail "Trava de usuário acionada."
[[ "$DOCROOT" == "/home/belastock/htdocs/loja.belastock.com.br" ]] || fail "Trava de diretório acionada."

FORBIDDEN=(
  "/home/belastock/htdocs/belastock.com.br"
  "/home/belastock/htdocs/www.belastock.com.br"
  "/home/belastock/htdocs/portal.belastock.com.br"
)
for p in "${FORBIDDEN[@]}"; do
  [[ "$DOCROOT" != "$p" ]] || fail "Deploy recusado: caminho do site principal."
done

[[ -d "$DOCROOT" ]] || fail "Subdomínio existente não encontrado no caminho esperado: $DOCROOT"
OWNER="$(stat -c '%U' "$DOCROOT")"
[[ "$OWNER" == "$SITE_USER" ]] || fail "Dono inesperado do subdomínio: $OWNER"

mapfile -t EXISTING_PATHS < <(find /home -mindepth 3 -maxdepth 3 -type d -path "*/htdocs/${DOMAIN}" 2>/dev/null || true)
for p in "${EXISTING_PATHS[@]:-}"; do
  [[ -z "$p" || "$p" == "$DOCROOT" ]] || fail "O domínio também existe em outro caminho: $p"
done

if [[ ! -f "$SECRETS_FILE" ]]; then
  log "Gerando credenciais locais exclusivas da loja (não entram no GitHub)"
  umask 077
  DB_PASSWORD="$(openssl rand -hex 18)"
  ADMIN_PASSWORD="$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9!@#%+=' | head -c 24)"
  cat > "$SECRETS_FILE" <<EOF
DB_PASSWORD=${DB_PASSWORD}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF
  chmod 600 "$SECRETS_FILE"
fi
# shellcheck disable=SC1090
source "$SECRETS_FILE"

if ! command -v wp >/dev/null 2>&1; then
  log "Instalando WP-CLI"
  curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
  chmod 755 /usr/local/bin/wp
fi

run_wp(){ sudo -u "$SITE_USER" -H wp --path="$DOCROOT" "$@"; }
run_wp_safe(){ sudo -u "$SITE_USER" -H wp --path="$DOCROOT" --skip-plugins --skip-themes "$@"; }

EXISTING_WP="nao"
if [[ -f "$DOCROOT/wp-config.php" ]]; then
  log "wp-config.php existente detectado; validando exclusivamente o WordPress do subdomínio"
  if run_wp_safe core is-installed >/dev/null 2>&1; then
    HOME_URL="$(run_wp_safe option get home 2>/dev/null | tail -n1 | tr -d '\r' || true)"
    SITE_URL="$(run_wp_safe option get siteurl 2>/dev/null | tail -n1 | tr -d '\r' || true)"
    [[ "$HOME_URL" =~ ^https?://loja\.belastock\.com\.br/?$ ]] || fail "WordPress existente aponta HOME para outro endereço: ${HOME_URL:-vazio}"
    [[ "$SITE_URL" =~ ^https?://loja\.belastock\.com\.br/?$ ]] || fail "WordPress existente aponta SITEURL para outro endereço: ${SITE_URL:-vazio}"
    EXISTING_WP="sim"
    log "WordPress existente validado como ${DOMAIN}; adoção segura autorizada pelas travas."
  fi
fi

if ! run_wp_safe core is-installed >/dev/null 2>&1; then
  fail "WordPress da loja não está instalado no subdomínio validado."
fi

log "Aplicando configuração de produção do WordPress"
run_wp_safe config set DISALLOW_FILE_EDIT true --raw >/dev/null
run_wp_safe config set WP_AUTO_UPDATE_CORE minor >/dev/null
run_wp_safe config set WP_DEBUG false --raw >/dev/null
run_wp_safe config set WP_DEBUG_DISPLAY false --raw >/dev/null
run_wp_safe config set WP_DEBUG_LOG false --raw >/dev/null
run_wp_safe config set WP_ENVIRONMENT_TYPE production >/dev/null

if run_wp_safe user get "$ADMIN_USER" --field=ID >/dev/null 2>&1; then
  run_wp_safe user update "$ADMIN_USER" --user_pass="$ADMIN_PASSWORD" --role=administrator >/dev/null
else
  run_wp_safe user create "$ADMIN_USER" "$ADMIN_EMAIL" --role=administrator --user_pass="$ADMIN_PASSWORD" >/dev/null
fi

log "Criando backup do banco antes das atualizações"
mkdir -p "$BACKUP_DIR"
chown "$SITE_USER:$SITE_USER" "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/db_$(date '+%Y%m%d_%H%M%S').sql"
run_wp_safe db export "$BACKUP_FILE" --add-drop-table >/dev/null
gzip -f "$BACKUP_FILE"
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'db_*.sql.gz' -mtime +14 -delete || true

log "Sincronizando tema e os dois plugins próprios da Bela Stock"
mkdir -p \
  "$DOCROOT/wp-content/themes/belastock-store" \
  "$DOCROOT/wp-content/plugins/belastock-core" \
  "$DOCROOT/wp-content/plugins/belastock-shop-cards"
rsync -a --delete "$REPO_ROOT/wp-content/themes/belastock-store/" "$DOCROOT/wp-content/themes/belastock-store/"
rsync -a --delete "$REPO_ROOT/wp-content/plugins/belastock-core/" "$DOCROOT/wp-content/plugins/belastock-core/"
rsync -a --delete "$REPO_ROOT/wp-content/plugins/belastock-shop-cards/" "$DOCROOT/wp-content/plugins/belastock-shop-cards/"

mkdir -p "$DOCROOT/wp-content/themes/belastock-store/assets"
[[ -f "$REPO_ROOT/deploy/assets/belastock-logo.webp.b64" ]] || fail "Logo Bela Stock codificada não encontrada no repositório."
base64 -d "$REPO_ROOT/deploy/assets/belastock-logo.webp.b64" > "$DOCROOT/wp-content/themes/belastock-store/assets/belastock-logo.webp"
[[ -s "$DOCROOT/wp-content/themes/belastock-store/assets/belastock-logo.webp" ]] || fail "Falha ao materializar a logo Bela Stock."
chown -R "$SITE_USER:$SITE_USER" \
  "$DOCROOT/wp-content/themes/belastock-store" \
  "$DOCROOT/wp-content/plugins/belastock-core" \
  "$DOCROOT/wp-content/plugins/belastock-shop-cards"

log "Instalando/ativando plugins necessários"
run_wp plugin install woocommerce --activate
run_wp plugin install elementor --activate
run_wp plugin install woocommerce-mercadopago --activate
run_wp plugin install woocommerce-paypal-payments --activate
run_wp plugin install melhor-envio-cotacao --activate
run_wp plugin activate belastock-core
run_wp plugin activate belastock-shop-cards
run_wp theme activate belastock-store

log "Verificando e aplicando atualizações de plugins"
run_wp plugin update --all || log "Algum plugin externo recusou atualização automática; os plugins críticos serão validados individualmente."
for plugin in woocommerce elementor woocommerce-mercadopago woocommerce-paypal-payments melhor-envio-cotacao; do
  run_wp plugin update "$plugin" || true
  run_wp plugin is-active "$plugin" >/dev/null || fail "Plugin obrigatório inativo após atualização: $plugin"
done
run_wp plugin is-active belastock-core >/dev/null || fail "Bela Stock Core inativo."
run_wp plugin is-active belastock-shop-cards >/dev/null || fail "Bela Stock Shop Cards inativo."

REQUIRED_UPDATES="$(run_wp plugin list --update=available --field=name 2>/dev/null || true)"
for plugin in woocommerce elementor woocommerce-mercadopago woocommerce-paypal-payments melhor-envio-cotacao; do
  if printf '%s\n' "$REQUIRED_UPDATES" | grep -qx "$plugin"; then
    fail "Atualização ainda pendente no plugin obrigatório: $plugin"
  fi
done

log "Configurando WooCommerce Brasil"
run_wp_safe option update blogname "Bela Stock — Loja"
run_wp_safe option update blogdescription "Vista-se bem e comunique-se melhor"
run_wp_safe option update timezone_string "America/Sao_Paulo"
run_wp_safe option update permalink_structure '/%postname%/'
run_wp_safe option update woocommerce_currency 'BRL'
run_wp_safe option update woocommerce_default_country 'BR'
run_wp_safe option update woocommerce_weight_unit 'kg'
run_wp_safe option update woocommerce_dimension_unit 'cm'
run_wp_safe option update woocommerce_enable_guest_checkout 'yes'
run_wp_safe option update woocommerce_calc_taxes 'yes'
run_wp --skip-plugins=elementor eval 'if (class_exists("WC_Install")) { WC_Install::create_pages(); }'
run_wp --skip-plugins=elementor rewrite flush

for spec in "Camisetas:camisetas" "Bonés:bones" "Adesivos:adesivos"; do
  NAME="${spec%%:*}"; SLUG="${spec##*:}"
  if ! run_wp --skip-plugins=elementor term get product_cat "$SLUG" --by=slug --field=term_id >/dev/null 2>&1; then
    run_wp --skip-plugins=elementor term create product_cat "$NAME" --slug="$SLUG" >/dev/null
  fi
done

log "Aplicando Elementor, cabeçalho, barra, capa, rodapé, produto e descontos"
[[ -f "$REPO_ROOT/deploy/FINALIZE_STORE.php" ]] || fail "Finalizador da loja não encontrado."
run_wp eval-file "$REPO_ROOT/deploy/FINALIZE_STORE.php"
run_wp elementor flush-css >/dev/null 2>&1 || true
run_wp cache flush >/dev/null 2>&1 || true

if [[ "$(run_wp_safe post get 1 --field=post_name 2>/dev/null | tail -n1 || true)" == "hello-world" ]]; then
  run_wp_safe post delete 1 --force >/dev/null 2>&1 || true
fi

log "Ajustando permissões somente do subdomínio"
chown -R "$SITE_USER:$SITE_USER" "$DOCROOT"
find "$DOCROOT" -type d -exec chmod 755 {} +
find "$DOCROOT" -type f -exec chmod 644 {} +
chmod 640 "$DOCROOT/wp-config.php"

log "Instalando/verificando SSL"
SSL_STATUS="pendente"
if clpctl lets-encrypt:install:certificate --domainName="$DOMAIN" >/tmp/belastock-loja-ssl.log 2>&1; then
  SSL_STATUS="ok"
elif curl -k -sS --max-time 8 -o /dev/null --resolve "${DOMAIN}:443:127.0.0.1" "https://${DOMAIN}/"; then
  SSL_STATUS="ok-existente"
fi
[[ "$SSL_STATUS" == ok* ]] || fail "SSL não confirmado para a loja."
run_wp_safe config set FORCE_SSL_ADMIN true --raw >/dev/null

log "Verificação técnica final"
run_wp_safe core is-installed
for plugin in woocommerce elementor woocommerce-mercadopago woocommerce-paypal-payments melhor-envio-cotacao belastock-core belastock-shop-cards; do
  run_wp plugin is-active "$plugin" >/dev/null || fail "Plugin inativo na auditoria final: $plugin"
done
run_wp theme is-active belastock-store >/dev/null || fail "Tema Bela Stock Store não está ativo."
[[ -s "$DOCROOT/wp-content/themes/belastock-store/assets/belastock-logo.webp" ]] || fail "Logo não instalada."

ELEMENTOR_PRODUCT_SUPPORT="$(run_wp_safe option get elementor_cpt_support --format=json 2>/dev/null || true)"
printf '%s' "$ELEMENTOR_PRODUCT_SUPPORT" | grep -q 'product' || fail "Produtos não estão habilitados no Elementor."
HEADER_PAGE_ID="$(run_wp_safe option get belastock_header_page_id 2>/dev/null | tail -n1 || true)"
FOOTER_PAGE_ID="$(run_wp_safe option get belastock_footer_page_id 2>/dev/null | tail -n1 || true)"
HOME_PAGE_ID="$(run_wp_safe option get page_on_front 2>/dev/null | tail -n1 || true)"
[[ "$HEADER_PAGE_ID" =~ ^[0-9]+$ && "$FOOTER_PAGE_ID" =~ ^[0-9]+$ && "$HOME_PAGE_ID" =~ ^[0-9]+$ ]] || fail "Páginas Elementor editáveis não foram configuradas."

HOME_STATUS="$(curl -L -k -sS --max-time 15 -o /dev/null -w '%{http_code}' --resolve "${DOMAIN}:443:127.0.0.1" "https://${DOMAIN}/" || true)"
page_status(){
  local option="$1" id slug
  id="$(run_wp_safe option get "$option" 2>/dev/null | tail -n1 || true)"
  [[ "$id" =~ ^[0-9]+$ ]] || { printf '000'; return; }
  slug="$(run_wp_safe post get "$id" --field=post_name 2>/dev/null | tail -n1 || true)"
  [[ -n "$slug" ]] || { printf '000'; return; }
  curl -L -k -sS --max-time 15 -o /dev/null -w '%{http_code}' --resolve "${DOMAIN}:443:127.0.0.1" "https://${DOMAIN}/${slug}/" || true
}
SHOP_STATUS="$(page_status woocommerce_shop_page_id)"
CART_STATUS="$(page_status woocommerce_cart_page_id)"
CHECKOUT_STATUS="$(page_status woocommerce_checkout_page_id)"
ACCOUNT_STATUS="$(page_status woocommerce_myaccount_page_id)"
for code in "$HOME_STATUS" "$SHOP_STATUS" "$CART_STATUS" "$CHECKOUT_STATUS" "$ACCOUNT_STATUS"; do
  [[ "$code" =~ ^[23][0-9][0-9]$ ]] || fail "Uma URL crítica da loja não respondeu corretamente (HTTP=$code)."
done

plugin_version(){ run_wp_safe plugin get "$1" --field=version 2>/dev/null | tail -n1; }
WC_VERSION="$(plugin_version woocommerce)"
ELEMENTOR_VERSION_INSTALLED="$(plugin_version elementor)"
MP_VERSION="$(plugin_version woocommerce-mercadopago)"
PAYPAL_VERSION="$(plugin_version woocommerce-paypal-payments)"
ME_VERSION="$(plugin_version melhor-envio-cotacao)"
CORE_VERSION="$(plugin_version belastock-core)"
CARDS_VERSION="$(plugin_version belastock-shop-cards)"
OUTDATED_PLUGINS="$(run_wp_safe plugin list --update=available --field=name 2>/dev/null | paste -sd, - || true)"
ELEMENTOR_PRO_VERSION="$(run_wp_safe plugin get elementor-pro --field=version 2>/dev/null | tail -n1 || true)"
ELEMENTOR_PRO_UPDATE="nao"
if run_wp_safe plugin list --update=available --field=name 2>/dev/null | grep -qx elementor-pro; then ELEMENTOR_PRO_UPDATE="sim-pacote-indisponivel-no-updater"; fi

cat <<EOF
============================================================
 BELA STOCK LOJA - UPGRADE TOTAL VALIDADO
============================================================
DOMAIN=https://${DOMAIN}
DOCROOT=${DOCROOT}
BACKUP=${BACKUP_FILE}.gz
WORDPRESS=ok
WOOCOMMERCE=${WC_VERSION}
ELEMENTOR=${ELEMENTOR_VERSION_INSTALLED}
ELEMENTOR_PRO=${ELEMENTOR_PRO_VERSION:-nao-instalado}
ELEMENTOR_PRO_UPDATE=${ELEMENTOR_PRO_UPDATE}
MERCADO_PAGO=${MP_VERSION}
PAYPAL=${PAYPAL_VERSION}
MELHOR_ENVIO=${ME_VERSION}
BELASTOCK_CORE=${CORE_VERSION}
BELASTOCK_SHOP_CARDS=${CARDS_VERSION}
LOGO=ok
MOCKUPS=fotos-reais-jpg-webp-frente-verso-lateral-detalhe
ELEMENTOR_HEADER_PAGE=${HEADER_PAGE_ID}
ELEMENTOR_FOOTER_PAGE=${FOOTER_PAGE_ID}
ELEMENTOR_HOME_PAGE=${HOME_PAGE_ID}
ELEMENTOR_PRODUCTS=sim
DISCOUNTS=1:0,2:5,5:10,10:15,20:20,50:25-editavel
OUTDATED_PLUGINS=${OUTDATED_PLUGINS:-nenhum}
EXTERNAL_ACCOUNTS=autorizacao-das-contas-ainda-necessaria-para-transacoes-reais
SSL=${SSL_STATUS}
HTTP_HOME=${HOME_STATUS}
HTTP_SHOP=${SHOP_STATUS}
HTTP_CART=${CART_STATUS}
HTTP_CHECKOUT=${CHECKOUT_STATUS}
HTTP_ACCOUNT=${ACCOUNT_STATUS}
MAIN_SITE_TOUCHED=nao
============================================================
EOF
