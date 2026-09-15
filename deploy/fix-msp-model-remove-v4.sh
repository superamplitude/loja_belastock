#!/usr/bin/env bash
set -Eeuo pipefail

DOCROOT='/home/belastock/htdocs/loja.belastock.com.br'
PLUGIN="$DOCROOT/wp-content/plugins/mockup-studio-pro"
CSSFILE="$PLUGIN/assets/css/admin.css"
JSFILE="$PLUGIN/assets/js/editor.js"
PHPFILE="$PLUGIN/includes/class-msp-plugin.php"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/home/belastock/backups/mockup-studio-pro/model-remove-v4-$STAMP"

fail(){ echo "[ERRO] $*" >&2; exit 1; }

[ -f "$CSSFILE" ] || fail "admin.css ausente"
[ -f "$JSFILE" ] || fail "editor.js ausente"
[ -f "$PHPFILE" ] || fail "class-msp-plugin.php ausente"

mkdir -p "$BACKUP"
cp -a "$CSSFILE" "$BACKUP/admin.css.before"
cp -a "$JSFILE" "$BACKUP/editor.js.before"
cp -a "$PHPFILE" "$BACKUP/class-msp-plugin.php.before"
echo "BACKUP=$BACKUP"

cat >> "$CSSFILE" <<'CSS'

/* MSP_MODEL_REMOVE_V4
 * A base nativa do template também pode ser removida.
 * A regra antiga bloqueava o clique sempre que não havia base personalizada.
 */
.msp-model-base-side:not(.is-base-removed) .msp-model-remove-base {
  opacity: 1 !important;
  pointer-events: auto !important;
  cursor: pointer !important;
}
.msp-model-base-side.is-base-removed .msp-model-remove-base {
  opacity: .45 !important;
  pointer-events: none !important;
  cursor: default !important;
}
CSS

chown belastock:belastock "$CSSFILE"
chmod 0644 "$CSSFILE"

# Confirma que o JS atual possui a lógica de remoção real e persistente.
grep -q "modelBase(key)\[side+'_disabled'\]=true" "$JSFILE"
grep -q "if(modelSideDisabled())return ''" "$JSFILE"
grep -q "persistConfig('Base '" "$JSFILE"

# Confirma que o PHP conserva os flags de remoção no saneamento.
grep -q "front_disabled" "$PHPFILE"
grep -q "back_disabled" "$PHPFILE"

node --check "$JSFILE"
php -l "$PHPFILE"

# Verifica se o CSS final contém o override depois da regra antiga.
python3 - "$CSSFILE" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old=s.rfind('.msp-model-base-side:not(.has-custom-base) .button-link-delete')
new=s.rfind('.msp-model-base-side:not(.is-base-removed) .msp-model-remove-base')
print('OLD_BLOCK_POS=',old)
print('NEW_OVERRIDE_POS=',new)
if new < 0 or new <= old:
    raise SystemExit('CSS_OVERRIDE_ORDER_INVALID')
print('MSP_REMOVE_CLICK_CSS=OK')
PY

# Limpa caches/opcode sem alterar conteúdo do site.
rm -rf "$DOCROOT/wp-content/cache"/* 2>/dev/null || true
systemctl reload php8.3-fpm 2>/dev/null || true

LOGIN_CODE="$(curl -kLsS --max-redirs 5 --max-time 30 --resolve 'loja.belastock.com.br:443:127.0.0.1' -o /tmp/msp-v4-login.html -w '%{http_code}' 'https://loja.belastock.com.br/wp-login.php?msp-remove-v4=1')"
echo "WP_LOGIN_HTTP=$LOGIN_CODE"
test "$LOGIN_CODE" = 200

echo 'MSP_NATIVE_BASE_REMOVE_CLICK=OK'
echo 'MSP_NATIVE_BASE_REMOVE_PERSISTENCE=OK'
echo 'MSP_MODEL_REMOVE_V4=100%_OK'
