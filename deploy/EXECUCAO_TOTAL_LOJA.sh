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
    HOME_URL="$(run_wp_safe option get home --format=plaintext 2>/dev/null | tail -n1 | tr -d '\r' || true)"
    SITE_URL="$(run_wp_safe option get siteurl --format=plaintext 2>/dev/null | tail -n1 | tr -d '\r' || true)"
    [[ "$HOME_URL" =~ ^https?://loja\.belastock\.com\.br/?$ ]] || fail "WordPress existente aponta HOME para outro endereço: ${HOME_URL:-vazio}"
    [[ "$SITE_URL" =~ ^https?://loja\.belastock\.com\.br/?$ ]] || fail "WordPress existente aponta SITEURL para outro endereço: ${SITE_URL:-vazio}"
    EXISTING_WP="sim"
    log "WordPress existente validado como ${DOMAIN}; adoção segura autorizada pelas travas."
  else
    log "wp-config.php existe, mas o WordPress ainda não está instalado. Será concluído usando a configuração existente."
  fi
else
  log "Nenhum wp-config.php encontrado; preparando WordPress novo apenas no subdomínio"
  if ! mysql -NBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'" 2>/dev/null | grep -qx "$DB_NAME"; then
    clpctl db:add \
      --domainName="$DOMAIN" \
      --databaseName="$DB_NAME" \
      --databaseUserName="$DB_USER" \
      --databaseUserPassword="$DB_PASSWORD"
  fi

  sudo -u "$SITE_USER" -H wp core download --path="$DOCROOT" --locale=pt_BR --force
  run_wp_safe config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASSWORD" --dbhost="127.0.0.1" --dbcharset="utf8mb4" --skip-check
  run_wp_safe config set DISALLOW_FILE_EDIT true --raw
  run_wp_safe config set WP_AUTO_UPDATE_CORE minor
fi

if ! run_wp_safe core is-installed >/dev/null 2>&1; then
  log "Instalando WordPress da loja"
  run_wp_safe core install \
    --url="https://${DOMAIN}" \
    --title="Bela Stock — Loja" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASSWORD" \
    --admin_email="$ADMIN_EMAIL" \
    --skip-email
else
  log "WordPress já instalado; preservando banco e conteúdo existentes."
fi

if run_wp_safe user get "$ADMIN_USER" --field=ID >/dev/null 2>&1; then
  log "Atualizando senha do administrador dedicado da loja"
  run_wp_safe user update "$ADMIN_USER" --user_pass="$ADMIN_PASSWORD" --role=administrator >/dev/null
else
  log "Criando administrador dedicado da loja"
  run_wp_safe user create "$ADMIN_USER" "$ADMIN_EMAIL" --role=administrator --user_pass="$ADMIN_PASSWORD" >/dev/null
fi

log "Sincronizando somente tema e plugin próprios da loja"
mkdir -p "$DOCROOT/wp-content/themes/belastock-store" "$DOCROOT/wp-content/plugins/belastock-core"
rsync -a --delete "$REPO_ROOT/wp-content/themes/belastock-store/" "$DOCROOT/wp-content/themes/belastock-store/"
rsync -a --delete "$REPO_ROOT/wp-content/plugins/belastock-core/" "$DOCROOT/wp-content/plugins/belastock-core/"
chown -R "$SITE_USER:$SITE_USER" "$DOCROOT/wp-content/themes/belastock-store" "$DOCROOT/wp-content/plugins/belastock-core"

log "Instalando WooCommerce e integrações"
run_wp plugin install woocommerce --activate
run_wp plugin install woocommerce-mercadopago --activate
run_wp plugin install woocommerce-paypal-payments --activate
run_wp plugin install melhor-envio-cotacao --activate
run_wp plugin activate belastock-core
run_wp theme activate belastock-store

log "Configurando WooCommerce Brasil"
run_wp_safe option update blogname "Bela Stock — Loja"
run_wp_safe option update blogdescription "Camisetas, bonés e adesivos"
run_wp_safe option update timezone_string "America/Sao_Paulo"
run_wp_safe option update permalink_structure '/%postname%/'
run_wp_safe option update woocommerce_currency 'BRL'
run_wp_safe option update woocommerce_default_country 'BR'
run_wp_safe option update woocommerce_weight_unit 'kg'
run_wp_safe option update woocommerce_dimension_unit 'cm'
run_wp_safe option update woocommerce_enable_guest_checkout 'yes'
run_wp_safe option update woocommerce_calc_taxes 'yes'
run_wp eval 'if (class_exists("WC_Install")) { WC_Install::create_pages(); }'
run_wp_safe rewrite flush

for spec in "Camisetas:camisetas" "Bonés:bones" "Adesivos:adesivos"; do
  NAME="${spec%%:*}"; SLUG="${spec##*:}"
  if ! run_wp_safe term get product_cat "$SLUG" --by=slug --field=term_id >/dev/null 2>&1; then
    run_wp_safe term create product_cat "$NAME" --slug="$SLUG" >/dev/null
  fi
done

if [[ "$(run_wp_safe post get 1 --field=post_name 2>/dev/null | tail -n1 || true)" == "hello-world" ]]; then
  run_wp_safe post delete 1 --force >/dev/null 2>&1 || true
fi

log "Ajustando permissões somente do subdomínio"
chown -R "$SITE_USER:$SITE_USER" "$DOCROOT"
find "$DOCROOT" -type d -exec chmod 755 {} +
find "$DOCROOT" -type f -exec chmod 644 {} +
chmod 640 "$DOCROOT/wp-config.php"

log "Tentando instalar SSL (falha de DNS não interrompe o deploy)"
SSL_STATUS="pendente"
if clpctl lets-encrypt:install:certificate --domainName="$DOMAIN" >/tmp/belastock-loja-ssl.log 2>&1; then
  SSL_STATUS="ok"
else
  log "SSL ainda não emitido; normalmente significa DNS ainda não apontado ou certificado já gerenciado."
fi

log "Verificação final"
run_wp_safe core is-installed
run_wp_safe plugin is-active woocommerce
run_wp_safe plugin is-active belastock-core
run_wp_safe theme is-active belastock-store

HTTP_STATUS="$(curl -L -k -sS --max-time 12 -o /dev/null -w '%{http_code}' --resolve "${DOMAIN}:443:127.0.0.1" "https://${DOMAIN}/" || true)"
if [[ "$HTTP_STATUS" == "000" ]]; then
  HTTP_STATUS="$(curl -L -sS --max-time 12 -o /dev/null -w '%{http_code}' --resolve "${DOMAIN}:80:127.0.0.1" "http://${DOMAIN}/" || true)"
fi

cat <<EOF
============================================================
 BELA STOCK LOJA - DEPLOY CONCLUIDO
============================================================
DOMAIN=https://${DOMAIN}
DOCROOT=${DOCROOT}
EXISTING_WORDPRESS_ADOPTED=${EXISTING_WP}
WORDPRESS=ok
WOOCOMMERCE=ok
THEME=belastock-store
ADMIN_USER=${ADMIN_USER}
ADMIN_SECRET_FILE=${SECRETS_FILE}
PRODUCT_VIEWS=frente,verso,lateral,detalhe,mockup
MERCADO_PAGO=plugin-ativo-credenciais-da-conta-necessarias
PAYPAL=plugin-ativo-conexao-da-conta-necessaria
MELHOR_ENVIO=plugin-ativo-token-da-conta-necessario
SSL=${SSL_STATUS}
HTTP_LOCAL=${HTTP_STATUS}
MAIN_SITE_TOUCHED=nao
============================================================
EOF
