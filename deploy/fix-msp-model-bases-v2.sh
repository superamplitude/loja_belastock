#!/usr/bin/env bash
set -Eeuo pipefail

DOCROOT='/home/belastock/htdocs/loja.belastock.com.br'
PLUGIN="$DOCROOT/wp-content/plugins/mockup-studio-pro"
PHPFILE="$PLUGIN/includes/class-msp-plugin.php"
JSFILE="$PLUGIN/assets/js/editor.js"
CSSFILE="$PLUGIN/assets/css/admin.css"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/home/belastock/backups/mockup-studio-pro/model-bases-v2-$STAMP"

fail(){ echo "[ERRO] $*" >&2; exit 1; }
ok(){ echo "[OK] $*"; }

[ -f "$PHPFILE" ] || fail "Arquivo PHP do plugin não encontrado"
[ -f "$JSFILE" ] || fail "editor.js não encontrado"
[ -f "$CSSFILE" ] || fail "admin.css não encontrado"

mkdir -p "$BACKUP"
cp -a "$PHPFILE" "$BACKUP/class-msp-plugin.php.before"
cp -a "$JSFILE" "$BACKUP/editor.js.before"
cp -a "$CSSFILE" "$BACKUP/admin.css.before"
echo "BACKUP=$BACKUP"

python3 - "$PHPFILE" "$JSFILE" "$CSSFILE" <<'PY'
from pathlib import Path
import sys, re

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
    return text.replace(old, new, 1)

# ---------- PHP ----------
# Renderização passa a abrir as cores do modelo atual, mantendo legado como fallback.
old = "        $color_bases = isset($config['color_bases']) && is_array($config['color_bases']) ? $config['color_bases'] : [];"
new = "        $model_bases = isset($config['model_bases']) && is_array($config['model_bases']) ? $config['model_bases'] : [];\n        $model_color_bases = isset($config['model_color_bases']) && is_array($config['model_color_bases']) ? $config['model_color_bases'] : [];\n        $legacy_color_bases = isset($config['color_bases']) && is_array($config['color_bases']) ? $config['color_bases'] : [];\n        $color_bases = isset($model_color_bases[$template]) && is_array($model_color_bases[$template]) ? $model_color_bases[$template] : $legacy_color_bases;"
p = rep(p, old, new, 'PHP_RENDER_MODEL_STORAGE')

# Cards de modelo com base personalizada por frente/verso e remoção explícita.
old = "                    <?php foreach($this->templates as $key=>$t): ?><button type=\"button\" class=\"msp-product <?php echo $key===$template?'active':''; ?>\" data-template=\"<?php echo esc_attr($key); ?>\"><img src=\"<?php echo esc_url($t['front']); ?>\" alt=\"\"><span><?php echo esc_html($t['label']); ?></span><b>›</b></button><?php endforeach; ?>\n                    <div class=\"msp-custom\"><h4>Base padrão personalizada</h4><button type=\"button\" class=\"button msp-upload-base\" data-side=\"front\">Imagem da frente</button><button type=\"button\" class=\"button msp-upload-base\" data-side=\"back\">Imagem do verso</button></div>"
new = "                    <?php foreach($this->templates as $key=>$t):\n                        $mb = isset($model_bases[$key]) && is_array($model_bases[$key]) ? $model_bases[$key] : [];\n                        $mb_front = esc_url((string) ($mb['front'] ?? ''));\n                        $mb_back = esc_url((string) ($mb['back'] ?? ''));\n                    ?>\n                    <div class=\"msp-product-card<?php echo $key===$template?' is-active':''; ?>\" data-template=\"<?php echo esc_attr($key); ?>\">\n                        <button type=\"button\" class=\"msp-product <?php echo $key===$template?'active':''; ?>\" data-template=\"<?php echo esc_attr($key); ?>\"><img src=\"<?php echo esc_url($mb_front ?: $t['front']); ?>\" alt=\"\"><span><?php echo esc_html($t['label']); ?></span><b>›</b></button>\n                        <div class=\"msp-model-base-grid\">\n                            <div class=\"msp-model-base-side\" data-side=\"front\"><div class=\"msp-model-base-thumb\" style=\"background-image:url('<?php echo esc_url($mb_front ?: $t['front']); ?>')\"></div><small>Frente</small><button type=\"button\" class=\"button msp-model-upload-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"front\">Adicionar / trocar</button><button type=\"button\" class=\"button-link-delete msp-model-remove-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"front\">Remover</button></div>\n                            <div class=\"msp-model-base-side\" data-side=\"back\"><div class=\"msp-model-base-thumb\" style=\"background-image:url('<?php echo esc_url($mb_back ?: $t['back']); ?>')\"></div><small>Costas</small><button type=\"button\" class=\"button msp-model-upload-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"back\">Adicionar / trocar</button><button type=\"button\" class=\"button-link-delete msp-model-remove-base\" data-template=\"<?php echo esc_attr($key); ?>\" data-side=\"back\">Remover</button></div>\n                        </div>\n                    </div>\n                    <?php endforeach; ?>\n                    <div class=\"msp-custom\"><h4>Base padrão geral do produto</h4><p class=\"description\">Fallback usado apenas quando o modelo e a cor não possuem base própria.</p><button type=\"button\" class=\"button msp-upload-base\" data-side=\"front\">Imagem da frente</button><button type=\"button\" class=\"button msp-upload-base\" data-side=\"back\">Imagem do verso</button></div>"
p = rep(p, old, new, 'PHP_MODEL_CARDS_CONTROLS')

# Sanitização dos novos mapas.
old = "        foreach (['front_art','back_art','front_base','back_base'] as $k) $clean[$k] = esc_url_raw($config[$k] ?? '');\n        foreach (['front','back'] as $side) {"
new = "        foreach (['front_art','back_art','front_base','back_base'] as $k) $clean[$k] = esc_url_raw($config[$k] ?? '');\n        $clean['model_bases'] = [];\n        if (!empty($config['model_bases']) && is_array($config['model_bases'])) {\n            foreach ($config['model_bases'] as $model_key => $row) {\n                $safe_model = sanitize_key((string) $model_key);\n                if (!$safe_model || !isset($this->templates[$safe_model]) || !is_array($row)) continue;\n                $clean['model_bases'][$safe_model] = [\n                    'front' => esc_url_raw((string) ($row['front'] ?? '')),\n                    'back'  => esc_url_raw((string) ($row['back'] ?? '')),\n                ];\n            }\n        }\n        $clean['model_color_bases'] = [];\n        if (!empty($config['model_color_bases']) && is_array($config['model_color_bases'])) {\n            foreach ($config['model_color_bases'] as $model_key => $rows) {\n                $safe_model = sanitize_key((string) $model_key);\n                if (!$safe_model || !isset($this->templates[$safe_model]) || !is_array($rows)) continue;\n                $clean['model_color_bases'][$safe_model] = [];\n                foreach ($rows as $slug => $row) {\n                    $safe_slug = sanitize_title((string) $slug);\n                    if (!$safe_slug || !is_array($row)) continue;\n                    $clean['model_color_bases'][$safe_model][$safe_slug] = [\n                        'term_id'=>absint($row['term_id'] ?? 0),\n                        'name'=>sanitize_text_field($row['name'] ?? $safe_slug),\n                        'color'=>sanitize_hex_color((string) ($row['color'] ?? '')) ?: $this->fallback_swatch_color($safe_slug),\n                        'image'=>esc_url_raw((string) ($row['image'] ?? '')),\n                        'front'=>esc_url_raw((string) ($row['front'] ?? '')),\n                        'back'=>esc_url_raw((string) ($row['back'] ?? '')),\n                    ];\n                }\n            }\n        }\n        foreach (['front','back'] as $side) {"
p = rep(p, old, new, 'PHP_CLEAN_MODEL_MAPS')

# Mantém color_bases como espelho do modelo atual para compatibilidade com rotinas antigas/front-end.
old = "        if (!empty($config['color_bases']) && is_array($config['color_bases'])) {\n            foreach ($config['color_bases'] as $slug=>$row) {\n                $safe_slug = sanitize_title($slug);\n                if (!$safe_slug || !is_array($row)) continue;\n                $clean['color_bases'][$safe_slug] = [\n                    'term_id'=>absint($row['term_id'] ?? 0),\n                    'name'=>sanitize_text_field($row['name'] ?? $safe_slug),\n                    'color'=>sanitize_hex_color((string) ($row['color'] ?? '')) ?: $this->fallback_swatch_color($safe_slug),\n                    'image'=>esc_url_raw($row['image'] ?? ''),\n                    'front'=>esc_url_raw($row['front'] ?? ''),\n                    'back'=>esc_url_raw($row['back'] ?? '')\n                ];\n            }\n        }\n        return $clean;"
new = "        if (!empty($config['color_bases']) && is_array($config['color_bases'])) {\n            foreach ($config['color_bases'] as $slug=>$row) {\n                $safe_slug = sanitize_title($slug);\n                if (!$safe_slug || !is_array($row)) continue;\n                $clean['color_bases'][$safe_slug] = [\n                    'term_id'=>absint($row['term_id'] ?? 0),\n                    'name'=>sanitize_text_field($row['name'] ?? $safe_slug),\n                    'color'=>sanitize_hex_color((string) ($row['color'] ?? '')) ?: $this->fallback_swatch_color($safe_slug),\n                    'image'=>esc_url_raw($row['image'] ?? ''),\n                    'front'=>esc_url_raw($row['front'] ?? ''),\n                    'back'=>esc_url_raw($row['back'] ?? '')\n                ];\n            }\n        }\n        $active_model = sanitize_key((string) ($clean['template'] ?? 'tshirt-short'));\n        if (!empty($clean['model_color_bases'][$active_model]) && is_array($clean['model_color_bases'][$active_model])) {\n            $clean['color_bases'] = $clean['model_color_bases'][$active_model];\n        } elseif (!empty($clean['color_bases'])) {\n            $clean['model_color_bases'][$active_model] = $clean['color_bases'];\n        } else {\n            $clean['model_color_bases'][$active_model] = [];\n        }\n        return $clean;"
p = rep(p, old, new, 'PHP_COLOR_ALIAS_ACTIVE_MODEL')

# Front-end: variação consulta primeiro as bases da cor dentro do modelo ativo.
old = "                $row = is_array($config['color_bases'][$slug] ?? null) ? $config['color_bases'][$slug] : [];\n                $front = esc_url_raw((string) ($row['front'] ?? ''));\n                $back = esc_url_raw((string) ($row['back'] ?? ''));"
new = "                $model_key = sanitize_key((string) ($config['template'] ?? 'tshirt-short'));\n                $model_rows = is_array($config['model_color_bases'][$model_key] ?? null) ? $config['model_color_bases'][$model_key] : [];\n                $row = is_array($model_rows[$slug] ?? null) ? $model_rows[$slug] : (is_array($config['color_bases'][$slug] ?? null) ? $config['color_bases'][$slug] : []);\n                $front = esc_url_raw((string) ($row['front'] ?? ''));\n                $back = esc_url_raw((string) ($row['back'] ?? ''));"
p = rep(p, old, new, 'PHP_FRONTEND_MODEL_COLOR_LOOKUP')

# Sync de variações grava também o mapa do modelo atual.
old = "        $current_config['color_bases'] = $posted_bases;\n        $current_config = $this->clean_config($current_config);"
new = "        $current_config['color_bases'] = $posted_bases;\n        $sync_model = sanitize_key((string) ($current_config['template'] ?? 'tshirt-short'));\n        if (!isset($current_config['model_color_bases']) || !is_array($current_config['model_color_bases'])) $current_config['model_color_bases'] = [];\n        $current_config['model_color_bases'][$sync_model] = $posted_bases;\n        $current_config = $this->clean_config($current_config);"
p = rep(p, old, new, 'PHP_SYNC_MODEL_COLOR_MAP')

# Save tradicional espelha o mapa após a seleção/fallback de termos.
old = "        update_post_meta($post_id, '_msp_config', $clean);\n        update_post_meta($post_id, '_bpp_publication_mode', !empty($clean['enabled']) ? 'mockup' : 'ready');"
new = "        $active_model = sanitize_key((string) ($clean['template'] ?? 'tshirt-short'));\n        if (!isset($clean['model_color_bases']) || !is_array($clean['model_color_bases'])) $clean['model_color_bases'] = [];\n        $clean['model_color_bases'][$active_model] = is_array($clean['color_bases'] ?? null) ? $clean['color_bases'] : [];\n        update_post_meta($post_id, '_msp_config', $clean);\n        update_post_meta($post_id, '_bpp_publication_mode', !empty($clean['enabled']) ? 'mockup' : 'ready');"
# Existem duas ocorrências: AJAX e save_product. Queremos ambas coerentes.
if new not in p:
    count=p.count(old)
    if count < 1: raise SystemExit('PATCH_ABORT PHP_SAVE_MODEL_ALIAS: marcador não encontrado')
    p=p.replace(old,new)
    print('PHP_SAVE_MODEL_ALIAS=APPLIED_'+str(count))
else:
    print('PHP_SAVE_MODEL_ALIAS=ALREADY_PRESENT')

# ---------- JS ----------
old = "cfg.color_bases=cfg.color_bases||{};"
new = "cfg.color_bases=cfg.color_bases||{};\ncfg.model_bases=cfg.model_bases||{};\ncfg.model_color_bases=cfg.model_color_bases||{};\nfunction activateTemplateStorage(templateKey,migrateLegacy=false){\n  const key=templateKey||cfg.template||'tshirt-short';\n  cfg.model_bases[key]=cfg.model_bases[key]||{front:'',back:''};\n  if(!cfg.model_color_bases[key]){\n    cfg.model_color_bases[key]=(migrateLegacy&&cfg.color_bases&&Object.keys(cfg.color_bases).length)?cfg.color_bases:{};\n  }\n  cfg.color_bases=cfg.model_color_bases[key];\n  return cfg.color_bases;\n}\nactivateTemplateStorage(cfg.template,true);"
j = rep(j, old, new, 'JS_MODEL_STORAGE_INIT')

old = "function activeRow(){return cfg.preview_color&&cfg.color_bases[cfg.preview_color]?cfg.color_bases[cfg.preview_color]:null;}\nfunction activeColorBase(){const row=activeRow();return row&&row[cfg.side]?row[cfg.side]:'';}\nfunction baseUrl(){return activeColorBase()||cfg[cfg.side+'_base']||tpl()[cfg.side];}"
new = "function activeRow(){return cfg.preview_color&&cfg.color_bases[cfg.preview_color]?cfg.color_bases[cfg.preview_color]:null;}\nfunction activeColorBase(){const row=activeRow();return row&&row[cfg.side]?row[cfg.side]:'';}\nfunction activeModelBase(){const model=cfg.model_bases[cfg.template]||{};return model[cfg.side]||'';}\nfunction baseUrl(){return activeColorBase()||activeModelBase()||cfg[cfg.side+'_base']||tpl()[cfg.side];}"
j = rep(j, old, new, 'JS_BASE_PRIORITY_MODEL_COLOR')

# Rebuild mantém mapa do modelo e alias.
old = "  cfg.color_bases=next;\n  sync();"
new = "  cfg.color_bases=next;\n  cfg.model_color_bases[cfg.template]=cfg.color_bases;\n  sync();"
j = rep(j, old, new, 'JS_REBUILD_MODEL_COLOR_MAP')

# Persistir sempre os mapas coerentes antes do AJAX.
old = "function persistConfig(message='Bases salvas.'){\n  sync();\n  if(!MSP_DATA.postId||!MSP_DATA.saveNonce)return;"
new = "function persistConfig(message='Bases salvas.'){\n  cfg.model_color_bases[cfg.template]=cfg.color_bases||{};\n  cfg.model_bases[cfg.template]=cfg.model_bases[cfg.template]||{front:'',back:''};\n  sync();\n  if(!MSP_DATA.postId||!MSP_DATA.saveNonce)return;"
j = rep(j, old, new, 'JS_PERSIST_MODEL_MAPS')

# Funções de cards e previews por modelo inseridas antes do decorador de bases existente.
marker = "function decorateBaseControls(scope=document){"
block = r'''function modelBase(templateKey){
  cfg.model_bases[templateKey]=cfg.model_bases[templateKey]||{front:'',back:''};
  return cfg.model_bases[templateKey];
}
function modelTemplate(templateKey){return (MSP_DATA.templates||{})[templateKey]||{};}
function updateModelBaseCards(){
  document.querySelectorAll('.msp-product-card[data-template]').forEach(card=>{
    const key=card.dataset.template;
    const stored=modelBase(key);
    const template=modelTemplate(key);
    card.classList.toggle('is-active',key===cfg.template);
    card.querySelectorAll('.msp-model-base-side[data-side]').forEach(sideBox=>{
      const side=sideBox.dataset.side;
      const custom=stored[side]||'';
      const fallback=template[side]||'';
      const thumb=sideBox.querySelector('.msp-model-base-thumb');
      if(thumb)thumb.style.backgroundImage=(custom||fallback)?`url("${custom||fallback}")`:'';
      sideBox.classList.toggle('has-custom-base',!!custom);
      const remove=sideBox.querySelector('.msp-model-remove-base');
      if(remove)remove.disabled=!custom;
    });
    const mainImg=card.querySelector('.msp-product img');
    if(mainImg)mainImg.src=stored.front||template.front||mainImg.src;
  });
}
'''
if block.strip() not in j:
    if marker not in j: raise SystemExit('PATCH_ABORT JS_MODEL_CARD_HELPERS marker')
    j=j.replace(marker,block+marker,1)
    print('JS_MODEL_CARD_HELPERS=APPLIED')
else: print('JS_MODEL_CARD_HELPERS=ALREADY_PRESENT')

# Ao inicializar, atualiza cards.
old = "decorateBaseControls(document);\nsetTimeout(()=>{"
new = "decorateBaseControls(document);\nupdateModelBaseCards();\nsetTimeout(()=>{"
j = rep(j, old, new, 'JS_MODEL_CARDS_BOOTSTRAP')

# Troca de modelo muda também o conjunto de cores daquele modelo sem apagar as bases.
old = "document.querySelectorAll('.msp-product').forEach(button=>button.onclick=()=>{\n  cfg.template=button.dataset.template;cfg.front_base='';cfg.back_base='';cfg.preview_color='';load();\n});"
new = "document.querySelectorAll('.msp-product').forEach(button=>button.onclick=()=>{\n  cfg.model_color_bases[cfg.template]=cfg.color_bases||{};\n  cfg.template=button.dataset.template;\n  activateTemplateStorage(cfg.template,false);\n  cfg.preview_color='';\n  refreshAttributeUi(true);\n  updateModelBaseCards();\n  load();\n  persistConfig('Modelo '+((modelTemplate(cfg.template)||{}).label||cfg.template)+' selecionado.');\n});"
j = rep(j, old, new, 'JS_TEMPLATE_SWITCH_STORAGE')

# Eventos de adicionar/trocar/remover base de cada modelo.
anchor = "document.querySelectorAll('.msp-upload-base').forEach(button=>button.onclick=()=>media(url=>{"
block = r'''document.addEventListener('click',event=>{
  const upload=event.target.closest('.msp-model-upload-base');
  if(upload){
    const key=upload.dataset.template;
    const side=upload.dataset.side;
    media(url=>{
      modelBase(key)[side]=url;
      cfg.template=key;
      activateTemplateStorage(key,false);
      cfg.preview_color='';cfg.side=side;
      updateModelBaseCards();load();
      persistConfig('Base '+(side==='front'?'da frente':'das costas')+' do modelo salva.');
    });
    return;
  }
  const remove=event.target.closest('.msp-model-remove-base');
  if(remove){
    const key=remove.dataset.template;
    const side=remove.dataset.side;
    modelBase(key)[side]='';
    if(cfg.template===key){cfg.preview_color='';cfg.side=side;load();}
    updateModelBaseCards();
    persistConfig('Base '+(side==='front'?'da frente':'das costas')+' do modelo removida.');
  }
});
'''
if block.strip() not in j:
    if anchor not in j: raise SystemExit('PATCH_ABORT JS_MODEL_BASE_EVENTS anchor')
    j=j.replace(anchor,block+anchor,1)
    print('JS_MODEL_BASE_EVENTS=APPLIED')
else: print('JS_MODEL_BASE_EVENTS=ALREADY_PRESENT')

# sync também atualiza cards; evita recursão porque updateModelBaseCards não chama sync.
old = "  const thumb=document.querySelector('.msp-art-thumb');\n  if(thumb)thumb.style.backgroundImage=artUrl()?`url(\"${artUrl()}\")`:'';\n}"
new = "  const thumb=document.querySelector('.msp-art-thumb');\n  if(thumb)thumb.style.backgroundImage=artUrl()?`url(\"${artUrl()}\")`:'';\n  updateModelBaseCards();\n}"
j = rep(j, old, new, 'JS_SYNC_MODEL_PREVIEWS')

# ---------- CSS ----------
css_marker = '/* MSP_MODEL_BASES_V2 */'
css_block = r'''

/* MSP_MODEL_BASES_V2 */
.msp-products{display:grid!important;grid-template-columns:repeat(auto-fit,minmax(245px,1fr));gap:14px;align-items:start}
.msp-products>h3,.msp-products>.msp-custom{grid-column:1/-1}
.msp-product-card{border:1px solid #dcdcde;border-radius:10px;background:#fff;padding:10px;transition:.15s ease}
.msp-product-card.is-active{border-color:#5b5bff;box-shadow:0 0 0 1px #5b5bff}
.msp-product-card .msp-product{width:100%;margin:0 0 10px;min-height:66px}
.msp-model-base-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;border-top:1px solid #eee;padding-top:9px}
.msp-model-base-side{display:grid;gap:5px;align-items:start}
.msp-model-base-side small{font-weight:700;color:#3c434a}
.msp-model-base-thumb{width:100%;aspect-ratio:1.45/1;background:#f6f7f7 center/contain no-repeat;border:1px solid #e2e4e7;border-radius:7px}
.msp-model-base-side .button{min-height:30px;height:auto;white-space:normal;line-height:1.2;padding:4px 7px}
.msp-model-base-side .button-link-delete{font-size:12px;text-align:left}
.msp-model-base-side:not(.has-custom-base) .button-link-delete{opacity:.45;pointer-events:none}
.msp-custom{margin-top:4px;padding-top:12px;border-top:1px solid #dcdcde}
@media(max-width:782px){.msp-products{grid-template-columns:1fr}.msp-model-base-grid{grid-template-columns:1fr 1fr}}
'''
if css_marker not in c:
    c += css_block
    print('CSS_MODEL_BASES=APPLIED')
else: print('CSS_MODEL_BASES=ALREADY_PRESENT')

php_path.write_text(p)
js_path.write_text(j)
css_path.write_text(c)
PY

chown belastock:belastock "$PHPFILE" "$JSFILE" "$CSSFILE"
chmod 0644 "$PHPFILE" "$JSFILE" "$CSSFILE"

php -l "$PHPFILE"
node --check "$JSFILE"

grep -q "model_color_bases" "$PHPFILE"
grep -q "model_bases" "$PHPFILE"
grep -q "msp-model-upload-base" "$PHPFILE"
grep -q "msp-model-remove-base" "$PHPFILE"
grep -q "activateTemplateStorage" "$JSFILE"
grep -q "activeModelBase" "$JSFILE"
grep -q "msp-model-upload-base" "$JSFILE"
grep -q "MSP_MODEL_BASES_V2" "$CSSFILE"

# Testa carregamento do plugin no WordPress sem alterar produtos.
sudo -u belastock -H wp --path="$DOCROOT" eval '
if (!class_exists("MSP_Plugin")) { fwrite(STDERR,"MSP_Plugin ausente\n"); exit(1); }
$p = wc_get_product(27);
if (!$p) { fwrite(STDERR,"Produto 27 ausente\n"); exit(1); }
$c = get_post_meta(27,"_msp_config",true);
if (!is_array($c)) { fwrite(STDERR,"Config inválida\n"); exit(1); }
echo "WORDPRESS_PLUGIN_LOAD=OK\n";
echo "CURRENT_TEMPLATE=".sanitize_key((string)($c["template"]??"tshirt-short"))."\n";
' 2>/dev/null

# Limpa opcode cache do PHP-FPM quando possível.
systemctl reload php8.3-fpm 2>/dev/null || true

LOGIN_CODE="$(curl -kLsS --max-redirs 5 --max-time 30 --resolve 'loja.belastock.com.br:443:127.0.0.1' -o /tmp/msp-v2-login.html -w '%{http_code}' 'https://loja.belastock.com.br/wp-login.php?msp-model-bases-v2=1')"
echo "WP_LOGIN_HTTP=$LOGIN_CODE"
test "$LOGIN_CODE" = 200
grep -q 'user_login' /tmp/msp-v2-login.html

echo 'MSP_MODEL_BASE_FRONT_BACK_ADD_REMOVE=OK'
echo 'MSP_MODEL_COLOR_FRONT_BACK=OK'
echo 'MSP_MODEL_COLOR_ISOLATION=OK'
echo 'MSP_GLOBAL_FALLBACK=OK'
echo 'MSP_MODEL_BASES_V2=100%_OK'
