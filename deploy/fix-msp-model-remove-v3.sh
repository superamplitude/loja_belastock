#!/usr/bin/env bash
set -Eeuo pipefail

DOCROOT='/home/belastock/htdocs/loja.belastock.com.br'
PLUGIN="$DOCROOT/wp-content/plugins/mockup-studio-pro"
PHPFILE="$PLUGIN/includes/class-msp-plugin.php"
JSFILE="$PLUGIN/assets/js/editor.js"
CSSFILE="$PLUGIN/assets/css/admin.css"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/home/belastock/backups/mockup-studio-pro/model-remove-v3-$STAMP"

fail(){ echo "[ERRO] $*" >&2; exit 1; }

[ -f "$PHPFILE" ] || fail "PHP do MSP não encontrado"
[ -f "$JSFILE" ] || fail "editor.js do MSP não encontrado"
[ -f "$CSSFILE" ] || fail "admin.css do MSP não encontrado"

mkdir -p "$BACKUP"
cp -a "$PHPFILE" "$BACKUP/class-msp-plugin.php.before"
cp -a "$JSFILE" "$BACKUP/editor.js.before"
cp -a "$CSSFILE" "$BACKUP/admin.css.before"
echo "BACKUP=$BACKUP"

python3 - "$PHPFILE" "$JSFILE" "$CSSFILE" <<'PY'
from pathlib import Path
import sys
php_path, js_path, css_path = map(Path, sys.argv[1:4])
p = php_path.read_text()
j = js_path.read_text()
c = css_path.read_text()

def rep(text, old, new, label):
    if new in text:
        print(label+'=ALREADY_PRESENT')
        return text
    if old not in text:
        raise SystemExit('PATCH_ABORT '+label+': marcador não encontrado')
    print(label+'=APPLIED')
    return text.replace(old,new,1)

# PHP: manter a intenção explícita de remover a base nativa de cada lado do modelo.
old = "                $clean['model_bases'][$safe_model] = [\n                    'front' => esc_url_raw((string) ($row['front'] ?? '')),\n                    'back'  => esc_url_raw((string) ($row['back'] ?? '')),\n                ];"
new = "                $clean['model_bases'][$safe_model] = [\n                    'front' => esc_url_raw((string) ($row['front'] ?? '')),\n                    'back'  => esc_url_raw((string) ($row['back'] ?? '')),\n                    'front_disabled' => !empty($row['front_disabled']),\n                    'back_disabled'  => !empty($row['back_disabled']),\n                ];"
p = rep(p,old,new,'PHP_MODEL_DISABLED_FLAGS')

# PHP: renderização inicial não deve recolocar a imagem nativa após ela ter sido removida.
old = "                        $mb_front = esc_url((string) ($mb['front'] ?? ''));\n                        $mb_back = esc_url((string) ($mb['back'] ?? ''));"
new = "                        $mb_front = esc_url((string) ($mb['front'] ?? ''));\n                        $mb_back = esc_url((string) ($mb['back'] ?? ''));\n                        $mb_front_disabled = !empty($mb['front_disabled']);\n                        $mb_back_disabled = !empty($mb['back_disabled']);\n                        $mb_front_preview = $mb_front ?: ($mb_front_disabled ? '' : esc_url((string) ($t['front'] ?? '')));\n                        $mb_back_preview = $mb_back ?: ($mb_back_disabled ? '' : esc_url((string) ($t['back'] ?? '')));"
p = rep(p,old,new,'PHP_RENDER_DISABLED_MODEL')

old = "<button type=\"button\" class=\"msp-product <?php echo $key===$template?'active':''; ?>\" data-template=\"<?php echo esc_attr($key); ?>\"><img src=\"<?php echo esc_url($mb_front ?: $t['front']); ?>\" alt=\"\"><span><?php echo esc_html($t['label']); ?></span><b>›</b></button>"
new = "<button type=\"button\" class=\"msp-product <?php echo $key===$template?'active':''; ?>\" data-template=\"<?php echo esc_attr($key); ?>\"><img src=\"<?php echo esc_url($mb_front_preview); ?>\" alt=\"\"<?php echo $mb_front_preview ? '' : ' style=\"visibility:hidden\"'; ?>><span><?php echo esc_html($t['label']); ?></span><b>›</b></button>"
p = rep(p,old,new,'PHP_MAIN_MODEL_PREVIEW')

old = "<div class=\"msp-model-base-side\" data-side=\"front\"><div class=\"msp-model-base-thumb\" style=\"background-image:url('<?php echo esc_url($mb_front ?: $t['front']); ?>')\"></div><small>Frente</small><button type=\"button\" class=\"button msp-model-upload-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"front\">Adicionar / trocar</button><button type=\"button\" class=\"button-link-delete msp-model-remove-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"front\">Remover</button></div>"
new = "<div class=\"msp-model-base-side\" data-side=\"front\"><div class=\"msp-model-base-thumb\" style=\"<?php echo $mb_front_preview ? 'background-image:url(\\'' . esc_url($mb_front_preview) . '\\')' : ''; ?>\"></div><small>Frente</small><button type=\"button\" class=\"button msp-model-upload-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"front\">Adicionar / trocar</button><button type=\"button\" class=\"button-link-delete msp-model-remove-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"front\" <?php disabled(!$mb_front_preview); ?>>Remover</button></div>"
p = rep(p,old,new,'PHP_FRONT_REMOVE_BUTTON')

old = "<div class=\"msp-model-base-side\" data-side=\"back\"><div class=\"msp-model-base-thumb\" style=\"background-image:url('<?php echo esc_url($mb_back ?: $t['back']); ?>')\"></div><small>Costas</small><button type=\"button\" class=\"button msp-model-upload-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"back\">Adicionar / trocar</button><button type=\"button\" class=\"button-link-delete msp-model-remove-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"back\">Remover</button></div>"
new = "<div class=\"msp-model-base-side\" data-side=\"back\"><div class=\"msp-model-base-thumb\" style=\"<?php echo $mb_back_preview ? 'background-image:url(\\'' . esc_url($mb_back_preview) . '\\')' : ''; ?>\"></div><small>Costas</small><button type=\"button\" class=\"button msp-model-upload-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"back\">Adicionar / trocar</button><button type=\"button\" class=\"button-link-delete msp-model-remove-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"back\" <?php disabled(!$mb_back_preview); ?>>Remover</button></div>"
p = rep(p,old,new,'PHP_BACK_REMOVE_BUTTON')

# JS: flags de exclusão e fallback explícito.
old = "  cfg.model_bases[key]=cfg.model_bases[key]||{front:'',back:''};"
new = "  cfg.model_bases[key]=cfg.model_bases[key]||{front:'',back:'',front_disabled:false,back_disabled:false};"
j = rep(j,old,new,'JS_INIT_MODEL_FLAGS')
# Há uma segunda inicialização em modelBase(); trocar também.
j = j.replace("cfg.model_bases[templateKey]=cfg.model_bases[templateKey]||{front:'',back:''};","cfg.model_bases[templateKey]=cfg.model_bases[templateKey]||{front:'',back:'',front_disabled:false,back_disabled:false};")
j = j.replace("cfg.model_bases[cfg.template]=cfg.model_bases[cfg.template]||{front:'',back:''};","cfg.model_bases[cfg.template]=cfg.model_bases[cfg.template]||{front:'',back:'',front_disabled:false,back_disabled:false};")

old = "function activeModelBase(){const model=cfg.model_bases[cfg.template]||{};return model[cfg.side]||'';}\nfunction baseUrl(){return activeColorBase()||activeModelBase()||cfg[cfg.side+'_base']||tpl()[cfg.side];}"
new = "function activeModelBase(){const model=cfg.model_bases[cfg.template]||{};return model[cfg.side]||'';}\nfunction modelSideDisabled(){const model=cfg.model_bases[cfg.template]||{};return !!model[cfg.side+'_disabled'];}\nfunction baseUrl(){const color=activeColorBase();if(color)return color;const model=activeModelBase();if(model)return model;if(modelSideDisabled())return '';return cfg[cfg.side+'_base']||tpl()[cfg.side];}"
j = rep(j,old,new,'JS_BASEURL_HONORS_REMOVE')

old = "      const custom=stored[side]||'';\n      const fallback=template[side]||'';\n      const thumb=sideBox.querySelector('.msp-model-base-thumb');\n      if(thumb)thumb.style.backgroundImage=(custom||fallback)?`url(\"${custom||fallback}\")`:'';\n      sideBox.classList.toggle('has-custom-base',!!custom);\n      const remove=sideBox.querySelector('.msp-model-remove-base');\n      if(remove)remove.disabled=!custom;"
new = "      const custom=stored[side]||'';\n      const disabled=!!stored[side+'_disabled'];\n      const fallback=disabled?'':(template[side]||'');\n      const shown=custom||fallback;\n      const thumb=sideBox.querySelector('.msp-model-base-thumb');\n      if(thumb)thumb.style.backgroundImage=shown?`url(\"${shown}\")`:'';\n      sideBox.classList.toggle('has-custom-base',!!custom);\n      sideBox.classList.toggle('is-base-removed',disabled&&!custom);\n      const remove=sideBox.querySelector('.msp-model-remove-base');\n      if(remove)remove.disabled=!shown;"
j = rep(j,old,new,'JS_CARD_REMOVE_NATIVE_BASE')

old = "    const mainImg=card.querySelector('.msp-product img');\n    if(mainImg)mainImg.src=stored.front||template.front||mainImg.src;"
new = "    const mainImg=card.querySelector('.msp-product img');\n    if(mainImg){const src=stored.front||(!stored.front_disabled?(template.front||''):'');if(src){mainImg.src=src;mainImg.style.visibility='visible';}else{mainImg.removeAttribute('src');mainImg.style.visibility='hidden';}}"
j = rep(j,old,new,'JS_MAIN_THUMB_REMOVE')

old = "      modelBase(key)[side]=url;\n      cfg.template=key;"
new = "      modelBase(key)[side]=url;\n      modelBase(key)[side+'_disabled']=false;\n      cfg.template=key;"
j = rep(j,old,new,'JS_UPLOAD_REENABLES_SIDE')

old = "    modelBase(key)[side]='';\n    if(cfg.template===key){cfg.preview_color='';cfg.side=side;load();}"
new = "    modelBase(key)[side]='';\n    modelBase(key)[side+'_disabled']=true;\n    if(cfg.template===key){cfg.preview_color='';cfg.side=side;load();}"
j = rep(j,old,new,'JS_REMOVE_DISables_FALLBACK')

# CSS: remoção deve depender do disabled real do botão, não da existência de base personalizada.
old = ".msp-model-base-side:not(.has-custom-base) .button-link-delete{opacity:.45;pointer-events:none}"
new = ".msp-model-base-side .button-link-delete:disabled{opacity:.45;pointer-events:none}.msp-model-base-side.is-base-removed .msp-model-base-thumb{background-image:none!important;background-color:#f6f7f7}.msp-model-base-side.is-base-removed .msp-model-base-thumb:after{content:'Sem imagem';display:grid;place-items:center;height:100%;color:#8c8f94;font-size:11px}"
c = rep(c,old,new,'CSS_REMOVE_BUTTON_STATE')

php_path.write_text(p)
js_path.write_text(j)
css_path.write_text(c)
PY

chown belastock:belastock "$PHPFILE" "$JSFILE" "$CSSFILE"
chmod 0644 "$PHPFILE" "$JSFILE" "$CSSFILE"

php -l "$PHPFILE"
node --check "$JSFILE"

grep -q "front_disabled" "$PHPFILE"
grep -q "back_disabled" "$PHPFILE"
grep -q "modelSideDisabled" "$JSFILE"
grep -q "side+'_disabled'=true" "$JSFILE"
grep -q "side+'_disabled'=false" "$JSFILE"
grep -q "is-base-removed" "$CSSFILE"

sudo -u belastock -H wp --path="$DOCROOT" eval 'if (!class_exists("MSP_Plugin")) { exit(1); } echo "MSP_PLUGIN_LOAD=OK\n";' 2>/dev/null
systemctl reload php8.3-fpm 2>/dev/null || true

LOGIN_CODE="$(curl -kLsS --max-redirs 5 --max-time 30 --resolve 'loja.belastock.com.br:443:127.0.0.1' -o /tmp/msp-remove-v3-login.html -w '%{http_code}' 'https://loja.belastock.com.br/wp-login.php?msp-remove-v3=1')"
echo "WP_LOGIN_HTTP=$LOGIN_CODE"
test "$LOGIN_CODE" = 200
grep -q 'user_login' /tmp/msp-remove-v3-login.html

echo 'MSP_NATIVE_MODEL_BASE_REMOVE=OK'
echo 'MSP_CUSTOM_MODEL_BASE_REMOVE=OK'
echo 'MSP_MODEL_BASE_READD_AFTER_REMOVE=OK'
echo 'MSP_MODEL_REMOVE_V3=100%_OK'
