#!/usr/bin/env bash
set -Eeuo pipefail
P='/home/belastock/htdocs/loja.belastock.com.br/wp-content/plugins/mockup-studio-pro'
PHP="$P/includes/class-msp-plugin.php"
JS="$P/assets/js/editor.js"
CSS="$P/assets/css/admin.css"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/home/belastock/backups/mockup-studio-pro/color-picker-v7-$STAMP"
mkdir -p "$BACKUP"
cp -a "$PHP" "$BACKUP/class-msp-plugin.php"
cp -a "$JS" "$BACKUP/editor.js"
cp -a "$CSS" "$BACKUP/admin.css"
echo "BACKUP=$BACKUP"

python3 - "$PHP" "$JS" "$CSS" <<'PY'
from pathlib import Path
import sys
php_path, js_path, css_path = map(Path, sys.argv[1:4])
php = php_path.read_text()
js = js_path.read_text()
css = css_path.read_text()

old = '<select id="msp_color_terms_select" name="msp_selected_color_terms[]" class="msp-color-terms-select" multiple size="8" aria-label="Cores disponíveis">'
new = '<select id="msp_color_terms_select" name="msp_selected_color_terms[]" class="msp-color-terms-select" multiple size="8" hidden aria-hidden="true" tabindex="-1" style="display:none!important" aria-label="Cores disponíveis">'
if old in php:
    php = php.replace(old, new, 1)
elif 'id="msp_color_terms_select"' not in php:
    raise SystemExit('select de cores não encontrado no PHP')

old_js = """if(termOptions)termOptions.addEventListener('click',event=>{\n  const button=event.target.closest('.msp-term-option[data-value]');\n  if(!button||!termSelect)return;\n  const option=[...termSelect.options].find(item=>item.value===button.dataset.value);\n  if(!option)return;\n  option.selected=!option.selected;\n  applyTermSelection();\n});"""
new_js = """if(termOptions)termOptions.addEventListener('click',event=>{\n  const button=event.target.closest('.msp-term-option[data-value]');\n  if(!button||!termSelect)return;\n  event.preventDefault();\n  event.stopPropagation();\n  const slug=button.dataset.value||'';\n  const option=[...termSelect.options].find(item=>item.value===slug);\n  if(!option)return;\n  const nextSelected=!option.selected;\n  option.selected=nextSelected;\n  button.classList.toggle('is-selected',nextSelected);\n  button.setAttribute('aria-pressed',nextSelected?'true':'false');\n  applyTermSelection();\n});"""
if old_js in js:
    js = js.replace(old_js, new_js, 1)
elif "event.preventDefault();" not in js or "aria-pressed" not in js:
    raise SystemExit('handler visual de cores não encontrado no JS')

old_sync = """termOptions.querySelectorAll('.msp-term-option[data-value]').forEach(button=>{\n    button.classList.toggle('is-selected',selected.has(button.dataset.value||''));\n  });"""
new_sync = """termOptions.querySelectorAll('.msp-term-option[data-value]').forEach(button=>{\n    const active=selected.has(button.dataset.value||'');\n    button.classList.toggle('is-selected',active);\n    button.setAttribute('aria-pressed',active?'true':'false');\n  });"""
if old_sync in js:
    js = js.replace(old_sync, new_sync, 1)

marker = '/* MSP_COLOR_PICKER_V7 */'
if marker not in css:
    css += r'''

/* MSP_COLOR_PICKER_V7 */
.msp-color-terms-select{display:none!important;visibility:hidden!important;position:absolute!important;left:-99999px!important;width:1px!important;height:1px!important;min-height:0!important;margin:0!important;padding:0!important;border:0!important;opacity:0!important;pointer-events:none!important}
.msp-term-picker{margin-left:0!important;overflow:visible!important}
.msp-term-options{display:flex!important;flex-wrap:wrap!important;gap:10px!important;padding:12px!important;border:1px solid #e2e8f0!important;border-radius:10px!important;background:#fff!important}
.msp-term-option{appearance:none!important;-webkit-appearance:none!important;position:relative!important;display:flex!important;flex:0 0 82px!important;min-height:82px!important;flex-direction:column!important;align-items:center!important;justify-content:flex-start!important;gap:7px!important;padding:8px 5px!important;border:1px solid #dbe3ec!important;border-radius:10px!important;background:#fff!important;color:#172033!important;cursor:pointer!important;pointer-events:auto!important;box-sizing:border-box!important;text-align:center!important}
.msp-term-option:hover{border-color:#8aa4c4!important;background:#f8fbff!important}
.msp-term-option.is-selected{border-color:#2563eb!important;background:#eff6ff!important;box-shadow:0 0 0 1px #2563eb!important}
.msp-term-option .msp-picker-swatch{display:block!important;width:38px!important;height:38px!important;flex:0 0 38px!important;border-radius:50%!important}
.msp-term-option .msp-term-label{display:block!important;width:100%!important;font-size:11px!important;line-height:1.2!important;white-space:normal!important;overflow:visible!important;color:#334155!important}
.msp-term-option .msp-term-check{display:none!important}
.msp-term-option.is-selected .msp-term-check{display:block!important}
.msp-term-option[aria-pressed="true"] .msp-picker-swatch{box-shadow:0 0 0 3px #2563eb!important}
'''

php_path.write_text(php)
js_path.write_text(js)
css_path.write_text(css)
PY

php -l "$PHP"
node --check "$JS"
grep -q 'hidden aria-hidden="true" tabindex="-1" style="display:none!important"' "$PHP"
grep -q 'MSP_COLOR_PICKER_V7' "$CSS"
grep -q "event.preventDefault();" "$JS"
grep -q "aria-pressed" "$JS"
chown belastock:belastock "$PHP" "$JS" "$CSS"

# Limpa caches de aplicação/transientes sem alterar conteúdo.
sudo -u belastock -H wp --path='/home/belastock/htdocs/loja.belastock.com.br' cache flush >/dev/null 2>&1 || true
if command -v systemctl >/dev/null 2>&1; then systemctl reload php8.3-fpm >/dev/null 2>&1 || true; fi

echo 'MSP_COLOR_NATIVE_SELECT=HIDDEN'
echo 'MSP_COLOR_SWATCH_CLICK=REBUILT'
echo 'MSP_COLOR_PICKER_V7=OK'
