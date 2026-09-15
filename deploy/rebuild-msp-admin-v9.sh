#!/usr/bin/env bash
set -Eeuo pipefail
DOCROOT='/home/belastock/htdocs/loja.belastock.com.br'
PLUGIN="$DOCROOT/wp-content/plugins/mockup-studio-pro"
PHPFILE="$PLUGIN/includes/class-msp-plugin.php"
JSFILE="$PLUGIN/assets/js/editor.js"
CSSFILE="$PLUGIN/assets/css/admin.css"
MAIN="$PLUGIN/mockup-studio-pro.php"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/home/belastock/backups/mockup-studio-pro/admin-v9-$STAMP"
mkdir -p "$BACKUP"
cp -a "$PHPFILE" "$BACKUP/class-msp-plugin.php.before"
cp -a "$JSFILE" "$BACKUP/editor.js.before"
cp -a "$CSSFILE" "$BACKUP/admin.css.before"
cp -a "$MAIN" "$BACKUP/mockup-studio-pro.php.before"
echo "BACKUP=$BACKUP"

python3 - "$PHPFILE" "$JSFILE" "$CSSFILE" "$MAIN" <<'PY'
from pathlib import Path
import sys,re
php,js,css,main=map(Path,sys.argv[1:])
p=php.read_text(); j=js.read_text(); c=css.read_text(); m=main.read_text()

def once(text,old,new,label):
    if old not in text:
        if new in text:
            print(label+'=ALREADY')
            return text
        raise SystemExit('PATCH_ABORT '+label)
    print(label+'=OK')
    return text.replace(old,new,1)

# 1) Estrutura visual real dos modelos: o CSS V8 esperava classes que o PHP nunca renderizava.
old='''                <aside class="msp-products"><h3>Produtos suportados</h3>
                    <?php foreach($this->templates as $key=>$t):'''
new='''                <aside class="msp-products msp-products-v9"><h3>Produtos suportados</h3>
                    <div id="msp_model_base_status" class="msp-base-manager-status" aria-live="polite"></div>
                    <div class="msp-model-picker-v9" role="group" aria-label="Modelos de produto">
                    <?php foreach($this->templates as $picker_key=>$picker_t):
                        $picker_mb = isset($model_bases[$picker_key]) && is_array($model_bases[$picker_key]) ? $model_bases[$picker_key] : [];
                        $picker_disabled = !empty($picker_mb['front_disabled']);
                        $picker_img = esc_url((string) ($picker_mb['front'] ?? '')) ?: ($picker_disabled ? '' : esc_url((string) ($picker_t['front'] ?? '')));
                    ?>
                        <button type="button" class="msp-model-picker-button<?php echo $picker_key===$template?' is-active':''; ?>" data-template="<?php echo esc_attr($picker_key); ?>" aria-pressed="<?php echo $picker_key===$template?'true':'false'; ?>">
                            <span class="msp-model-picker-thumb"><?php if ($picker_img): ?><img src="<?php echo esc_url($picker_img); ?>" alt=""><?php endif; ?></span>
                            <span><?php echo esc_html($picker_t['label']); ?></span>
                        </button>
                    <?php endforeach; ?>
                    </div>
                    <div class="msp-active-model-title-v9"><strong id="msp_active_model_name"><?php echo esc_html($this->templates[$template]['label'] ?? 'Modelo'); ?></strong><small>Gerencie frente e costas do modelo selecionado.</small></div>
                    <?php foreach($this->templates as $key=>$t):'''
p=once(p,old,new,'PHP_MODEL_PICKER')

# 2) Base geral com remover explícito; não depende de botão criado depois por JS.
old='''                    <div class="msp-custom"><h4>Base padrão geral do produto</h4><p class="description">Fallback usado apenas quando o modelo e a cor não possuem base própria.</p><button type="button" class="button msp-upload-base" data-side="front">Imagem da frente</button><button type="button" class="button msp-upload-base" data-side="back">Imagem do verso</button></div>'''
new='''                    <div class="msp-custom"><div class="msp-custom-copy"><h4>Base padrão geral do produto</h4><p class="description">Fallback usado quando modelo e cor não possuem base própria.</p></div><div class="msp-default-base-control"><button type="button" class="button msp-upload-base" data-side="front">Adicionar / trocar frente</button><button type="button" class="button-link-delete msp-remove-base" data-side="front">Remover frente</button></div><div class="msp-default-base-control"><button type="button" class="button msp-upload-base" data-side="back">Adicionar / trocar costas</button><button type="button" class="button-link-delete msp-remove-base" data-side="back">Remover costas</button></div></div>'''
p=once(p,old,new,'PHP_DEFAULT_BASE_CONTROLS')

# 3) Remover frente/verso por cor já renderizado pelo PHP.
old='''                        <td><div class="msp-base-thumb" style="background-image:url('<?php echo esc_url($row['front'] ?? ''); ?>')"></div><button type="button" class="button msp-color-upload" data-side="front">Selecionar frente</button></td>
                        <td><div class="msp-base-thumb" style="background-image:url('<?php echo esc_url($row['back'] ?? ''); ?>')"></div><button type="button" class="button msp-color-upload" data-side="back">Selecionar verso</button></td>'''
new='''                        <td><div class="msp-base-thumb" style="background-image:url('<?php echo esc_url($row['front'] ?? ''); ?>')"></div><button type="button" class="button msp-color-upload" data-side="front">Adicionar / trocar frente</button><button type="button" class="button-link-delete msp-color-remove-base" data-side="front">Remover frente</button></td>
                        <td><div class="msp-base-thumb" style="background-image:url('<?php echo esc_url($row['back'] ?? ''); ?>')"></div><button type="button" class="button msp-color-upload" data-side="back">Adicionar / trocar costas</button><button type="button" class="button-link-delete msp-color-remove-base" data-side="back">Remover costas</button></td>'''
p=once(p,old,new,'PHP_COLOR_REMOVE_CONTROLS')

# 4) JS: atualizar cards, picker e título sempre juntos.
old='''    const mainImg=card.querySelector('.msp-product img');
    if(mainImg){const src=stored.front||(!stored.front_disabled?(template.front||''):'');if(src){mainImg.src=src;mainImg.style.visibility='visible';}else{mainImg.removeAttribute('src');mainImg.style.visibility='hidden';}}
  });
}'''
new='''    const mainImg=card.querySelector('.msp-product img');
    const src=stored.front||(!stored.front_disabled?(template.front||''):'');
    if(mainImg){if(src){mainImg.src=src;mainImg.style.visibility='visible';}else{mainImg.removeAttribute('src');mainImg.style.visibility='hidden';}}
    const picker=document.querySelector('.msp-model-picker-button[data-template="'+selectorEscape(key)+'"]');
    if(picker){
      picker.classList.toggle('is-active',key===cfg.template);
      picker.setAttribute('aria-pressed',key===cfg.template?'true':'false');
      const img=picker.querySelector('img');
      const thumb=picker.querySelector('.msp-model-picker-thumb');
      if(src){if(img)img.src=src;else if(thumb){const ni=document.createElement('img');ni.src=src;ni.alt='';thumb.replaceChildren(ni);}}
      else if(thumb)thumb.replaceChildren();
    }
  });
  const title=document.getElementById('msp_active_model_name');
  if(title)title.textContent=(modelTemplate(cfg.template)||{}).label||cfg.template||'Modelo';
}'''
j=once(j,old,new,'JS_UPDATE_PICKER')

# 5) JS: seleção do modelo centralizada. Corrige o fato de o novo picker não ter handler.
old='''document.querySelectorAll('.msp-product').forEach(button=>button.onclick=()=>{
  cfg.model_color_bases[cfg.template]=cfg.color_bases||{};
  cfg.template=button.dataset.template;
  activateTemplateStorage(cfg.template,false);
  cfg.preview_color='';
  refreshAttributeUi(true);
  updateModelBaseCards();
  load();
  persistConfig('Modelo '+((modelTemplate(cfg.template)||{}).label||cfg.template)+' selecionado.');
});'''
new='''function selectMspTemplate(templateKey){
  if(!templateKey||!modelTemplate(templateKey))return;
  cfg.model_color_bases[cfg.template]=cfg.color_bases||{};
  cfg.template=templateKey;
  activateTemplateStorage(cfg.template,false);
  cfg.preview_color='';
  refreshAttributeUi(true);
  updateModelBaseCards();
  load();
  persistConfig('Modelo '+((modelTemplate(cfg.template)||{}).label||cfg.template)+' selecionado.');
}
document.querySelectorAll('.msp-product,.msp-model-picker-button').forEach(button=>button.onclick=()=>selectMspTemplate(button.dataset.template));'''
j=once(j,old,new,'JS_MODEL_PICKER_HANDLER')

# 6) Evita dois listeners competirem e permite estado busy visual.
old="""  const upload=event.target.closest('.msp-model-upload-base');
  if(upload){
    const key=upload.dataset.template;
    const side=upload.dataset.side;
    media(url=>{
      modelBase(key)[side]=url;
      modelBase(key)[side+'_disabled']=false;
      cfg.template=key;
      activateTemplateStorage(key,false);
      cfg.preview_color='';cfg.side=side;
      updateModelBaseCards();load();syncHiddenConfig();
      persistBaseManagerAction('model',key,side,'add',url);
    });
    return;
  }"""
new="""  const upload=event.target.closest('.msp-model-upload-base');
  if(upload){
    event.preventDefault();event.stopPropagation();
    const key=upload.dataset.template;
    const side=upload.dataset.side;
    media(url=>{
      upload.disabled=true;
      modelBase(key)[side]=url;
      modelBase(key)[side+'_disabled']=false;
      cfg.template=key;
      activateTemplateStorage(key,false);
      cfg.preview_color='';cfg.side=side;
      updateModelBaseCards();load();syncHiddenConfig();
      persistBaseManagerAction('model',key,side,'add',url).always(()=>{upload.disabled=false;});
    });
    return;
  }"""
j=once(j,old,new,'JS_MODEL_UPLOAD_BUSY')

old="""  const remove=event.target.closest('.msp-model-remove-base');
  if(remove){
    const key=remove.dataset.template;
    const side=remove.dataset.side;
    modelBase(key)[side]='';
    modelBase(key)[side+'_disabled']=true;
    if(cfg.template===key){cfg.preview_color='';cfg.side=side;load();}
    updateModelBaseCards();syncHiddenConfig();
    persistBaseManagerAction('model',key,side,'remove','');
  }"""
new="""  const remove=event.target.closest('.msp-model-remove-base');
  if(remove){
    event.preventDefault();event.stopPropagation();
    const key=remove.dataset.template;
    const side=remove.dataset.side;
    remove.disabled=true;
    modelBase(key)[side]='';
    modelBase(key)[side+'_disabled']=true;
    if(cfg.template===key){cfg.preview_color='';cfg.side=side;load();}
    updateModelBaseCards();syncHiddenConfig();
    persistBaseManagerAction('model',key,side,'remove','').always(()=>{updateModelBaseCards();});
  }"""
j=once(j,old,new,'JS_MODEL_REMOVE_BUSY')

# 7) Status também aparece no status geral caso necessário.
old="""function setBaseManagerStatus(message,type=''){
  if(!baseManagerStatus)return;
  baseManagerStatus.textContent=message||'';
  baseManagerStatus.className='msp-base-manager-status'+(type?' is-'+type:'');
}"""
new="""function setBaseManagerStatus(message,type=''){
  if(baseManagerStatus){
    baseManagerStatus.textContent=message||'';
    baseManagerStatus.className='msp-base-manager-status'+(type?' is-'+type:'');
  }
  if(type==='error'&&typeof setSyncStatus==='function')setSyncStatus(message||'Erro ao salvar base.','error');
}"""
j=once(j,old,new,'JS_STATUS_FALLBACK')

# 8) CSS: remove bloco experimental V8 e aplica layout consistente V9.
marker='/* MSP_ADMIN_LAYOUT_V8 */'
if marker in c:
    c=c.split(marker,1)[0].rstrip()+"\n\n"
else:
    print('CSS_V8_BLOCK=NOT_FOUND')

v9=r'''/* MSP_ADMIN_LAYOUT_V9 — painel estável, compacto e sem controles sobrepostos */
.msp-app{--msp9-bg:#f7f8fb;--msp9-card:#fff;--msp9-line:#dfe3e8;--msp9-text:#182230;--msp9-muted:#667085;--msp9-primary:#5b5bff;--msp9-danger:#b42318;--msp9-success:#067647}
.msp-app,.msp-app *{box-sizing:border-box}
.msp-color-terms-select{display:none!important;visibility:hidden!important;position:absolute!important;left:-99999px!important;width:1px!important;height:1px!important;min-height:0!important;margin:0!important;padding:0!important;border:0!important;opacity:0!important;pointer-events:none!important}
.msp-grid{grid-template-columns:minmax(0,1fr) 340px!important;gap:14px!important;align-items:start!important}
.msp-products-v9{grid-column:1/-1!important;display:block!important;padding:16px!important;border:1px solid var(--msp9-line)!important;border-radius:12px!important;background:var(--msp9-bg)!important}
.msp-products-v9>h3{margin:0 0 10px!important;font-size:15px!important;color:var(--msp9-text)!important}
.msp-base-manager-status{display:none;margin:0 0 10px!important;padding:8px 10px!important;border:1px solid var(--msp9-line);border-radius:8px;background:#fff;font-size:12px;font-weight:600}
.msp-base-manager-status:not(:empty){display:block}.msp-base-manager-status.is-loading{background:#eff6ff;border-color:#bfdbfe;color:#1d4ed8}.msp-base-manager-status.is-success{background:#ecfdf3;border-color:#abefc6;color:var(--msp9-success)}.msp-base-manager-status.is-error{background:#fef3f2;border-color:#fecdca;color:var(--msp9-danger)}
.msp-model-picker-v9{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:8px;margin:0 0 12px}
.msp-model-picker-button{appearance:none;display:flex;align-items:center;gap:8px;min-width:0;min-height:58px;padding:8px;border:1px solid var(--msp9-line);border-radius:10px;background:#fff;color:#1d2939;cursor:pointer;text-align:left}
.msp-model-picker-button:hover{border-color:#aab4c1;background:#fcfcfd}.msp-model-picker-button.is-active{border-color:var(--msp9-primary);background:#f2f3ff;box-shadow:0 0 0 1px rgba(91,91,255,.15)}
.msp-model-picker-thumb{display:grid;place-items:center;width:40px;height:40px;flex:0 0 40px;border-radius:7px;background:#f4f5f7;overflow:hidden}.msp-model-picker-thumb img{width:100%;height:100%;object-fit:contain}.msp-model-picker-button>span:last-child{min-width:0;font-size:11px;font-weight:700;line-height:1.2;overflow-wrap:anywhere}
.msp-active-model-title-v9{display:flex;justify-content:space-between;align-items:center;gap:12px;margin:0 0 8px;padding:0 2px}.msp-active-model-title-v9 strong{font-size:13px;color:var(--msp9-text)}.msp-active-model-title-v9 small{font-size:11px;color:var(--msp9-muted)}
.msp-products-v9 .msp-product-card{display:none!important;margin:0!important;padding:0!important;border:0!important;background:transparent!important;box-shadow:none!important}.msp-products-v9 .msp-product-card.is-active{display:block!important}.msp-products-v9 .msp-product-card>.msp-product{display:none!important}
.msp-products-v9 .msp-model-base-grid{display:grid!important;grid-template-columns:1fr 1fr!important;gap:10px!important;padding:0!important;border:0!important}
.msp-products-v9 .msp-model-base-side{display:grid!important;grid-template-columns:110px minmax(0,1fr) 90px;grid-template-rows:auto auto;gap:6px 10px!important;align-items:center!important;padding:10px!important;border:1px solid var(--msp9-line)!important;border-radius:10px!important;background:#fff!important}
.msp-products-v9 .msp-model-base-thumb{grid-column:1;grid-row:1/3;width:110px!important;height:82px!important;margin:0!important;border:1px solid #e4e7ec!important;border-radius:8px!important;background:#f8fafc center/contain no-repeat!important}
.msp-products-v9 .msp-model-base-side>small{grid-column:2;grid-row:1;margin:0!important;font-size:11px!important;color:#344054!important}.msp-products-v9 .msp-model-base-side>small:after{margin-left:6px!important;font-size:9px!important}
.msp-products-v9 .msp-model-base-side .button{grid-column:2;grid-row:2;justify-self:start;width:auto!important;min-height:30px!important;margin:0!important;padding:4px 10px!important;font-size:11px!important;font-weight:600!important}
.msp-products-v9 .msp-model-base-side .button-link-delete{grid-column:3;grid-row:1/3;display:flex!important;align-items:center;justify-content:center;width:90px!important;min-height:32px!important;margin:0!important;padding:5px 8px!important;border:1px solid #fecdca!important;border-radius:7px!important;background:#fff!important;color:var(--msp9-danger)!important;text-decoration:none!important;font-size:10px!important;font-weight:600!important;cursor:pointer!important}.msp-products-v9 .msp-model-base-side .button-link-delete:disabled{opacity:.4!important;cursor:not-allowed!important}
.msp-custom{display:grid!important;grid-template-columns:minmax(0,1fr) 210px 210px!important;gap:10px!important;align-items:stretch!important;margin:10px 0 0!important;padding:10px!important;border:1px dashed #d0d5dd!important;border-radius:10px!important;background:#fff!important}.msp-custom-copy{align-self:center}.msp-custom h4{margin:0 0 3px!important;font-size:12px!important}.msp-custom p{margin:0!important;font-size:11px!important;color:var(--msp9-muted)!important}.msp-default-base-control{display:flex;flex-direction:column;gap:6px}.msp-default-base-control .button{width:100%!important;margin:0!important}.msp-default-base-control .button-link-delete{display:flex!important;align-items:center;justify-content:center;min-height:28px;padding:4px 8px;border:1px solid #fecdca!important;border-radius:7px;background:#fff;color:var(--msp9-danger)!important;text-decoration:none!important;font-size:10px!important}
.msp-color-manager{padding:16px!important}.msp-term-picker{margin-left:0!important}.msp-attribute-actions,.msp-sync-status{margin-left:0!important}.msp-term-options{display:flex!important;flex-wrap:wrap!important;gap:8px!important;padding:9px!important}.msp-term-option{flex:0 0 72px!important;min-height:72px!important;padding:6px 4px!important}.msp-term-option.is-selected{border-color:#2563eb!important;background:#eff6ff!important;box-shadow:0 0 0 1px #2563eb!important}.msp-term-option .msp-picker-swatch{width:32px!important;height:32px!important;flex-basis:32px!important}.msp-term-option .msp-term-label{font-size:10px!important}
.msp-color-table-wrap{overflow:auto!important}.msp-color-table{min-width:900px}.msp-color-row td{vertical-align:top!important}.msp-color-row .msp-color-upload,.msp-color-row .msp-color-remove-base{display:block!important;width:130px!important;margin:6px 0 0!important}.msp-color-row .msp-color-remove-base{padding:5px 7px!important;border:1px solid #fecdca!important;border-radius:7px!important;background:#fff!important;color:var(--msp9-danger)!important;text-align:center!important;text-decoration:none!important;font-size:10px!important}.msp-base-thumb{width:130px!important;height:92px!important;background:#f8fafc center/contain no-repeat!important}
@media(max-width:1280px){.msp-model-picker-v9{grid-template-columns:repeat(3,minmax(0,1fr))}.msp-products-v9 .msp-model-base-grid{grid-template-columns:1fr!important}}
@media(max-width:980px){.msp-grid{grid-template-columns:1fr!important}.msp-custom{grid-template-columns:1fr 1fr!important}.msp-custom-copy{grid-column:1/-1}}
@media(max-width:782px){.msp-model-picker-v9{grid-template-columns:repeat(2,minmax(0,1fr))}.msp-products-v9 .msp-model-base-side{grid-template-columns:90px minmax(0,1fr);grid-template-rows:auto auto auto}.msp-products-v9 .msp-model-base-thumb{width:90px!important;height:72px!important}.msp-products-v9 .msp-model-base-side .button-link-delete{grid-column:2;grid-row:3;width:auto!important;justify-self:start}.msp-active-model-title-v9{align-items:flex-start;flex-direction:column;gap:2px}}
@media(max-width:520px){.msp-model-picker-v9{grid-template-columns:1fr 1fr}.msp-custom{grid-template-columns:1fr!important}.msp-default-base-control{grid-column:1}}
'''
c += v9

# 9) versão para invalidar caches e deixar a revisão identificável.
m=m.replace('Version: 1.9.0','Version: 1.9.1',1).replace("define('MSP_VERSION', '1.9.0');","define('MSP_VERSION', '1.9.1');",1)

php.write_text(p); js.write_text(j); css.write_text(c); main.write_text(m)
PY

php -l "$PHPFILE"
node --check "$JSFILE"

grep -q 'msp-products msp-products-v9' "$PHPFILE"
grep -q 'msp-model-picker-v9' "$PHPFILE"
grep -q 'msp_model_base_status' "$PHPFILE"
grep -q 'Adicionar / trocar frente' "$PHPFILE"
grep -q 'msp-color-remove-base' "$PHPFILE"
grep -q 'selectMspTemplate' "$JSFILE"
grep -q 'msp-model-picker-button' "$JSFILE"
grep -q 'MSP_ADMIN_LAYOUT_V9' "$CSSFILE"
! grep -q 'MSP_ADMIN_LAYOUT_V8' "$CSSFILE"
grep -q "define('MSP_VERSION', '1.9.1')" "$MAIN"

# Renderização de metabox para confirmar DOM final sem depender do navegador.
sudo -u belastock -H wp --path="$DOCROOT" eval '$p=get_post(27); if(!$p) exit(2); ob_start(); (Mockup_Studio_Pro::instance())->render_metabox($p); $h=ob_get_clean(); file_put_contents("/tmp/msp-v9-metabox.html",$h); echo "HTML_BYTES=".strlen($h)."\n";'
grep -q 'msp-model-picker-v9' /tmp/msp-v9-metabox.html
grep -q 'msp-products-v9' /tmp/msp-v9-metabox.html
grep -q 'msp_color_terms_select' /tmp/msp-v9-metabox.html
COUNT_PICKER="$(grep -o 'msp-model-picker-button' /tmp/msp-v9-metabox.html | wc -l)"
COUNT_UPLOAD="$(grep -o 'msp-model-upload-base' /tmp/msp-v9-metabox.html | wc -l)"
COUNT_REMOVE="$(grep -o 'msp-model-remove-base' /tmp/msp-v9-metabox.html | wc -l)"
echo "PICKER_BUTTONS=$COUNT_PICKER MODEL_UPLOAD_BUTTONS=$COUNT_UPLOAD MODEL_REMOVE_BUTTONS=$COUNT_REMOVE"
test "$COUNT_PICKER" -eq 6
test "$COUNT_UPLOAD" -eq 12
test "$COUNT_REMOVE" -eq 12

# Testes reais de persistência com rollback automático do produto usado em homologação.
STATE='/tmp/msp-v9-original-state.ser'
sudo -u belastock -H wp --path="$DOCROOT" eval '$c=get_post_meta(27,"_msp_config",true); file_put_contents("/tmp/msp-v9-original-state.ser",serialize($c)); echo "META_BACKUP=OK\n";'
restore(){ sudo -u belastock -H wp --path="$DOCROOT" eval '$c=unserialize(file_get_contents("/tmp/msp-v9-original-state.ser")); update_post_meta(27,"_msp_config",$c); echo "META_RESTORED\n";' >/dev/null || true; }
trap restore EXIT

run_action(){
  local scope="$1" template="$2" side="$3" mode="$4" url="$5" slug="${6:-}"
  sudo -u belastock -H env SCOPE="$scope" TEMPLATE="$template" SIDE="$side" MODE="$mode" URLV="$url" SLUG="$slug" wp --path="$DOCROOT" eval '
    wp_set_current_user(1);
    $_POST=["nonce"=>wp_create_nonce("msp_base_manager"),"post_id"=>27,"scope"=>getenv("SCOPE"),"template"=>getenv("TEMPLATE"),"side"=>getenv("SIDE"),"mode"=>getenv("MODE"),"url"=>getenv("URLV"),"slug"=>getenv("SLUG")]; $_REQUEST=$_POST; do_action("wp_ajax_msp_base_manager_action");
  '
}
OUT="$(run_action model tshirt-short front add 'https://example.com/v9-front.png')"; echo "$OUT" | grep -q '"success":true'
sudo -u belastock -H wp --path="$DOCROOT" eval '$c=get_post_meta(27,"_msp_config",true); if(($c["model_bases"]["tshirt-short"]["front"]??"")!=="https://example.com/v9-front.png")exit(1); echo "MODEL_ADD=OK\n";'
OUT="$(run_action model tshirt-short front remove '')"; echo "$OUT" | grep -q '"success":true'
sudo -u belastock -H wp --path="$DOCROOT" eval '$c=get_post_meta(27,"_msp_config",true);$r=$c["model_bases"]["tshirt-short"]??[];if(($r["front"]??"x")!==""||empty($r["front_disabled"]))exit(1);echo "MODEL_REMOVE=OK\n";'
OUT="$(run_action default tshirt-short back add 'https://example.com/v9-default.png')"; echo "$OUT" | grep -q '"success":true'
OUT="$(run_action default tshirt-short back remove '')"; echo "$OUT" | grep -q '"success":true'
COLOR_SLUG="$(sudo -u belastock -H wp --path="$DOCROOT" term list pa_cor --field=slug 2>/dev/null | head -n1 || true)"
if [ -n "$COLOR_SLUG" ]; then
  OUT="$(run_action color tshirt-short front add 'https://example.com/v9-color.png' "$COLOR_SLUG")"; echo "$OUT" | grep -q '"success":true'
  OUT="$(run_action color tshirt-short front remove '' "$COLOR_SLUG")"; echo "$OUT" | grep -q '"success":true'
  echo "COLOR_ADD_REMOVE=OK"
fi
restore; trap - EXIT

# Verificações WordPress e endpoint administrativo.
sudo -u belastock -H wp --path="$DOCROOT" plugin is-active mockup-studio-pro
LOGIN_CODE="$(curl -kLsS --max-redirs 5 --max-time 30 -o /tmp/msp-v9-login.html -w '%{http_code}' 'https://loja.belastock.com.br/wp-login.php')"
test "$LOGIN_CODE" = 200
grep -q 'user_login' /tmp/msp-v9-login.html

echo 'MSP_ADMIN_V9=100%_OK'
