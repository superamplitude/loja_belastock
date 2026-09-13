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

# Travas rígidas contra qualquer operação no site principal ou em outros vhosts.
FORBIDDEN=(
  "/home/belastock/htdocs/belastock.com.br"
  "/home/belastock/htdocs/www.belastock.com.br"
  "/home/belastock/htdocs/portal.belastock.com.br"
)
for p in "${FORBIDDEN[@]}"; do
  [[ "$DOCROOT" != "$p" ]] || fail "Deploy recusado: caminho do site principal."
done

# O subdomínio já existe no CloudPanel. Não criar, mover ou recriar vhost.
[[ -d "$DOCROOT" ]] || fail "Subdomínio existente não encontrado no caminho esperado: $DOCROOT"
OWNER="$(stat -c '%U' "$DOCROOT")"
[[ "$OWNER" == "$SITE_USER" ]] || fail "Dono inesperado do subdomínio: $OWNER"

# Recusar caso o mesmo domínio apareça em outro caminho.
mapfile -t EXISTING_PATHS < <(find /home -mindepth 3 -maxdepth 3 -type d -path "*/htdocs/${DOMAIN}" 2>/dev/null || true)
for p in "${EXISTING_PATHS[@]:-}"; do
  [[ -z "$p" || "$p" == "$DOCROOT" ]] || fail "O domínio também existe em outro caminho: $p"
done

# Se já houver um WordPress não criado por este deploy, não assumir controle.
if [[ -f "$DOCROOT/wp-config.php" && ! -f "$SECRETS_FILE" ]]; then
  fail "WordPress existente sem arquivo local de credenciais. Nenhuma alteração foi feita."
fi

if [[ ! -f "$SECRETS_FILE" ]]; then
  log "Gerando credenciais locais exclusivas da loja (não entram no GitHub)"
  umask 077
  DB_PASSWORD="$(openssl rand -hex 18)"
  ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9!@#%+=' | head -c 24)"
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

if [[ ! -f "$DOCROOT/wp-config.php" ]]; then
  log "Criando banco dedicado da loja"
  if ! mysql -NBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'" | grep -qx "$DB_NAME"; then
    clpctl db:add \
      --domainName="$DOMAIN" \
      --databaseName="$DB_NAME" \
      --databaseUserName="$DB_USER" \
      --databaseUserPassword="$DB_PASSWORD"
  fi

  log "Baixando WordPress pt-BR somente no subdomínio"
  sudo -u "$SITE_USER" -H wp core download --path="$DOCROOT" --locale=pt_BR --force
  run_wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASSWORD" --dbhost="127.0.0.1" --dbcharset="utf8mb4" --skip-check
  run_wp config set DISALLOW_FILE_EDIT true --raw
  run_wp config set WP_AUTO_UPDATE_CORE minor
fi

if ! run_wp core is-installed >/dev/null 2>&1; then
  log "Instalando WordPress da loja"
  run_wp core install \
    --url="https://${DOMAIN}" \
    --title="Bela Stock — Loja" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASSWORD" \
    --admin_email="$ADMIN_EMAIL" \
    --skip-email
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
run_wp option update blogname "Bela Stock — Loja"
run_wp option update blogdescription "Camisetas, bonés e adesivos"
run_wp option update timezone_string "America/Sao_Paulo"
run_wp option update permalink_structure '/%postname%/'
run_wp option update woocommerce_currency 'BRL'
run_wp option update woocommerce_default_country 'BR'
run_wp option update woocommerce_weight_unit 'kg'
run_wp option update woocommerce_dimension_unit 'cm'
run_wp option update woocommerce_enable_guest_checkout 'yes'
run_wp option update woocommerce_calc_taxes 'yes'
run_wp eval 'if (class_exists("WC_Install")) { WC_Install::create_pages(); }'
run_wp rewrite flush

for spec in "Camisetas:camisetas" "Bonés:bones" "Adesivos:adesivos"; do
  NAME="${spec%%:*}"; SLUG="${spec##*:}"
  if ! run_wp term get product_cat "$SLUG" --by=slug --field=term_id >/dev/null 2>&1; then
    run_wp term create product_cat "$NAME" --slug="$SLUG" >/dev/null
  fi
done

# Remover apenas conteúdo padrão do WordPress, nunca produtos do usuário.
run_wp post delete 1 --force >/dev/null 2>&1 || true

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
run_wp core is-installed
run_wp plugin is-active woocommerce
run_wp plugin is-active belastock-core
run_wp theme is-active belastock-store

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
WORDPRESS=ok
WOOCOMMERCE=ok
THEME=belastock-store
PRODUCT_VIEWS=frente,verso,lateral,detalhe,mockup
MERCADO_PAGO=plugin-ativo-credenciais-da-conta-necessarias
PAYPAL=plugin-ativo-conexao-da-conta-necessaria
MELHOR_ENVIO=plugin-ativo-token-da-conta-necessario
SSL=${SSL_STATUS}
HTTP_LOCAL=${HTTP_STATUS}
SECRETS=${SECRETS_FILE}
MAIN_SITE_TOUCHED=nao
============================================================
EOF
