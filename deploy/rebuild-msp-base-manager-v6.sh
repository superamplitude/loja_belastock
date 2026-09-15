#!/usr/bin/env bash
set -Eeuo pipefail

DOCROOT='/home/belastock/htdocs/loja.belastock.com.br'
PLUGIN="$DOCROOT/wp-content/plugins/mockup-studio-pro"
PHPFILE="$PLUGIN/includes/class-msp-plugin.php"
JSFILE="$PLUGIN/assets/js/editor.js"
CSSFILE="$PLUGIN/assets/css/admin.css"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/home/belastock/backups/mockup-studio-pro/base-manager-v6-$STAMP"
mkdir -p "$BACKUP"
cp -a "$PHPFILE" "$BACKUP/class-msp-plugin.php.before"
cp -a "$JSFILE" "$BACKUP/editor.js.before"
cp -a "$CSSFILE" "$BACKUP/admin.css.before"
echo "BACKUP=$BACKUP"

python3 - "$PHPFILE" "$JSFILE" "$CSSFILE" <<'PY'
from pathlib import Path
import sys
php=Path(sys.argv[1]); js=Path(sys.argv[2]); css=Path(sys.argv[3])
p=php.read_text(); j=js.read_text(); c=css.read_text()

def replace_once(text, old, new, label):
    if new in text:
        print(label+'=ALREADY_PRESENT')
        return text
    if old not in text:
        raise SystemExit('PATCH_ABORT '+label)
    print(label+'=APPLIED')
    return text.replace(old,new,1)

# PHP: rota AJAX única e robusta para todas as imagens de base.
hook="        add_action('wp_ajax_msp_model_base_action', [$this, 'ajax_model_base_action']);"
new_hook=hook+"\n        add_action('wp_ajax_msp_base_manager_action', [$this, 'ajax_base_manager_action']);"
p=replace_once(p,hook,new_hook,'PHP_BASE_MANAGER_HOOK')

nonce="            'modelBaseNonce'=>wp_create_nonce('msp_model_base'),"
new_nonce=nonce+"\n            'baseManagerNonce'=>wp_create_nonce('msp_base_manager'),"
p=replace_once(p,nonce,new_nonce,'PHP_BASE_MANAGER_NONCE')

marker="    public function ajax_model_base_action(): void {"
method=r'''    public function ajax_base_manager_action(): void {
        check_ajax_referer('msp_base_manager', 'nonce');
        $post_id = absint($_POST['post_id'] ?? 0);
        $scope = sanitize_key(wp_unslash($_POST['scope'] ?? ''));
        $template = sanitize_key(wp_unslash($_POST['template'] ?? ''));
        $side = sanitize_key(wp_unslash($_POST['side'] ?? ''));
        $mode = sanitize_key(wp_unslash($_POST['mode'] ?? ''));
        $slug = sanitize_title(wp_unslash($_POST['slug'] ?? ''));
        $url = esc_url_raw(wp_unslash($_POST['url'] ?? ''));

        if (!$post_id || !current_user_can('edit_post', $post_id)) {
            wp_send_json_error(['message'=>'Produto inválido ou sem permissão.'], 403);
        }
        if (!in_array($scope, ['default','model','color'], true)) {
            wp_send_json_error(['message'=>'Tipo de base inválido.'], 400);
        }
        if (!in_array($side, ['front','back'], true) || !in_array($mode, ['add','remove'], true)) {
            wp_send_json_error(['message'=>'Operação de base inválida.'], 400);
        }
        if ($mode === 'add' && !$url) {
            wp_send_json_error(['message'=>'Selecione uma imagem válida.'], 400);
        }
        if (($scope === 'model' || $scope === 'color') && (!isset($this->templates[$template]))) {
            wp_send_json_error(['message'=>'Modelo de produto inválido.'], 400);
        }
        if ($scope === 'color' && !$slug) {
            wp_send_json_error(['message'=>'Cor inválida.'], 400);
        }

        $config = get_post_meta($post_id, '_msp_config', true);
        if (!is_array($config)) $config = [];
        if (!array_key_exists('enabled', $config)) $config['enabled'] = true;
        if (empty($config['template'])) $config['template'] = $template ?: 'tshirt-short';

        if ($scope === 'default') {
            $config[$side.'_base'] = $mode === 'add' ? $url : '';
        }

        if ($scope === 'model') {
            if (!isset($config['model_bases']) || !is_array($config['model_bases'])) $config['model_bases'] = [];
            if (!isset($config['model_bases'][$template]) || !is_array($config['model_bases'][$template])) {
                $config['model_bases'][$template] = ['front'=>'','back'=>'','front_disabled'=>false,'back_disabled'=>false];
            }
            $config['model_bases'][$template][$side] = $mode === 'add' ? $url : '';
            $config['model_bases'][$template][$side.'_disabled'] = $mode === 'remove';
        }

        if ($scope === 'color') {
            if (!isset($config['model_color_bases']) || !is_array($config['model_color_bases'])) $config['model_color_bases'] = [];
            if (!isset($config['model_color_bases'][$template]) || !is_array($config['model_color_bases'][$template])) $config['model_color_bases'][$template] = [];
            $existing = is_array($config['model_color_bases'][$template][$slug] ?? null) ? $config['model_color_bases'][$template][$slug] : [];
            $taxonomy = sanitize_key((string) ($config['color_attribute'] ?? 'pa_cor'));
            $term = (strpos($taxonomy, 'pa_') === 0 && taxonomy_exists($taxonomy)) ? get_term_by('slug', $slug, $taxonomy) : false;
            $term_id = ($term && !is_wp_error($term)) ? (int) $term->term_id : absint($existing['term_id'] ?? 0);
            $name = ($term && !is_wp_error($term)) ? (string) $term->name : sanitize_text_field($existing['name'] ?? $slug);
            $color = $term_id ? (sanitize_hex_color((string) get_term_meta($term_id, '_msp_swatch_color', true)) ?: $this->fallback_swatch_color($slug)) : (sanitize_hex_color((string) ($existing['color'] ?? '')) ?: $this->fallback_swatch_color($slug));
            $image = $term_id ? esc_url_raw((string) get_term_meta($term_id, '_msp_swatch_image', true)) : esc_url_raw((string) ($existing['image'] ?? ''));
            $row = [
                'term_id'=>$term_id,
                'name'=>$name,
                'color'=>$color,
                'image'=>$image,
                'front'=>esc_url_raw((string) ($existing['front'] ?? '')),
                'back'=>esc_url_raw((string) ($existing['back'] ?? '')),
            ];
            $row[$side] = $mode === 'add' ? $url : '';
            $config['model_color_bases'][$template][$slug] = $row;
            if (sanitize_key((string) ($config['template'] ?? '')) === $template) {
                $config['color_bases'] = $config['model_color_bases'][$template];
            }
        }

        $clean = $this->clean_config($config);
        update_post_meta($post_id, '_msp_config', $clean);
        update_post_meta($post_id, '_bpp_publication_mode', !empty($clean['enabled']) ? 'mockup' : 'ready');

        wp_send_json_success([
            'message' => $mode === 'remove' ? 'Imagem de base removida e salva.' : 'Imagem de base salva.',
            'config' => $clean,
            'scope' => $scope,
            'template' => $template,
            'side' => $side,
            'slug' => $slug,
        ]);
    }

'''
if 'public function ajax_base_manager_action(): void {' not in p:
    if marker not in p: raise SystemExit('PATCH_ABORT PHP_BASE_MANAGER_METHOD')
    p=p.replace(marker,method+marker,1)
    print('PHP_BASE_MANAGER_METHOD=APPLIED')
else:
    print('PHP_BASE_MANAGER_METHOD=ALREADY_PRESENT')

# AJAX genérico faz merge com o meta atual: evita apagar bases de outros modelos.
old="""        $current = get_post_meta($post_id, '_msp_config', true);
        if (!is_array($current)) $current = [];
        if (!array_key_exists('enabled', $posted)) $posted['enabled'] = $this->is_mockup_enabled($current);
        $clean = $this->clean_config($posted);"""
new="""        $current = get_post_meta($post_id, '_msp_config', true);
        if (!is_array($current)) $current = [];
        if (!array_key_exists('enabled', $posted)) $posted['enabled'] = $this->is_mockup_enabled($current);
        $merged = $current;
        foreach ($posted as $key => $value) $merged[$key] = $value;
        $clean = $this->clean_config($merged);"""
p=replace_once(p,old,new,'PHP_GENERIC_SAVE_MERGE')

# JS: status dedicado do gerenciador de bases.
anchor="const importButton=document.getElementById('msp_import_colors');"
status_code=anchor+r'''
const productsPanel=document.querySelector('.msp-products');
let baseManagerStatus=document.getElementById('msp_model_base_status');
if(productsPanel&&!baseManagerStatus){
  baseManagerStatus=document.createElement('div');
  baseManagerStatus.id='msp_model_base_status';
  baseManagerStatus.className='msp-base-manager-status';
  const title=productsPanel.querySelector('h3');
  if(title)title.insertAdjacentElement('afterend',baseManagerStatus);else productsPanel.prepend(baseManagerStatus);
}
function setBaseManagerStatus(message,type=''){
  if(!baseManagerStatus)return;
  baseManagerStatus.textContent=message||'';
  baseManagerStatus.className='msp-base-manager-status'+(type?' is-'+type:'');
}
'''
j=replace_once(j,anchor,status_code,'JS_BASE_MANAGER_STATUS')

# JS: helper dedicado para default, modelo e cor.
anchor2="function modelBase(templateKey){"
helper=r'''function persistBaseManagerAction(scope,templateKey,side,mode,url='',slug='',after=null){
  const postId=currentPostId();
  if(!postId||!MSP_DATA.baseManagerNonce){
    setBaseManagerStatus('Não foi possível identificar o produto para salvar a base.','error');
    return $.Deferred().reject().promise();
  }
  setBaseManagerStatus(mode==='remove'?'Removendo imagem…':'Salvando imagem…','loading');
  return $.post(MSP_DATA.ajaxUrl,{
    action:'msp_base_manager_action',nonce:MSP_DATA.baseManagerNonce,post_id:postId,
    scope:scope,template:templateKey||cfg.template||'',side:side,mode:mode,url:url||'',slug:slug||''
  }).done(resp=>{
    if(!(resp&&resp.success&&resp.data&&resp.data.config)){
      setBaseManagerStatus(resp&&resp.data&&resp.data.message?resp.data.message:'Não foi possível salvar a imagem.','error');
      return;
    }
    const preview=cfg.preview_color||'';
    Object.assign(cfg,resp.data.config);
    cfg.model_bases=cfg.model_bases||{};
    cfg.model_color_bases=cfg.model_color_bases||{};
    activateTemplateStorage(cfg.template||templateKey||'tshirt-short',false);
    cfg.preview_color=preview;
    syncHiddenConfig();
    updateModelBaseCards();
    if(typeof after==='function')after(resp.data);
    load();
    setBaseManagerStatus(resp.data.message||'Imagem salva.','success');
  }).fail(xhr=>{
    const msg=xhr&&xhr.responseJSON&&xhr.responseJSON.data&&xhr.responseJSON.data.message?xhr.responseJSON.data.message:'Erro de comunicação ao salvar a imagem.';
    setBaseManagerStatus(msg,'error');
  });
}

'''
if 'function persistBaseManagerAction(' not in j:
    if anchor2 not in j: raise SystemExit('PATCH_ABORT JS_BASE_MANAGER_HELPER')
    j=j.replace(anchor2,helper+anchor2,1); print('JS_BASE_MANAGER_HELPER=APPLIED')
else: print('JS_BASE_MANAGER_HELPER=ALREADY_PRESENT')

# Modelos: sempre usar a nova rota.
j=j.replace("persistModelBaseDirect(key,side,'add',url);","persistBaseManagerAction('model',key,side,'add',url);",1)
j=j.replace("persistModelBaseDirect(key,side,'remove','');","persistBaseManagerAction('model',key,side,'remove','');",1)
print('JS_MODEL_ACTIONS_V6=APPLIED')

# Base padrão geral: rota direta e persistente.
old="""document.querySelectorAll('.msp-upload-base').forEach(button=>button.onclick=()=>media(url=>{
  cfg[button.dataset.side+'_base']=url;cfg.preview_color='';cfg.side=button.dataset.side;load();
  persistConfig('Base padrão '+(button.dataset.side==='front'?'da frente':'do verso')+' salva.');
}));
document.addEventListener('click',event=>{
  const button=event.target.closest('.msp-remove-base');if(!button)return;
  const side=button.dataset.side;cfg[side+'_base']='';if(cfg.preview_color==='')cfg.side=side;load();
  persistConfig('Base padrão '+(side==='front'?'da frente':'do verso')+' removida.');
});"""
new="""document.querySelectorAll('.msp-upload-base').forEach(button=>button.onclick=()=>media(url=>{
  const side=button.dataset.side;
  cfg[side+'_base']=url;cfg.preview_color='';cfg.side=side;load();syncHiddenConfig();
  persistBaseManagerAction('default',cfg.template,side,'add',url);
}));
document.addEventListener('click',event=>{
  const button=event.target.closest('.msp-remove-base');if(!button)return;
  const side=button.dataset.side;cfg[side+'_base']='';if(cfg.preview_color==='')cfg.side=side;load();syncHiddenConfig();
  persistBaseManagerAction('default',cfg.template,side,'remove','');
});"""
j=replace_once(j,old,new,'JS_DEFAULT_BASE_ACTIONS_V6')

# Cores: rota direta, sem depender do save genérico.
old="""      rebuildColors();
      cfg.preview_color=row.dataset.slug||slugify((row.querySelector('.msp-color-slug')||{}).value||(row.querySelector('.msp-color-name')||{}).value);
      cfg.side=side;load();persistConfig('Base '+(side==='front'?'da frente':'do verso')+' salva para este atributo.');"""
new="""      rebuildColors();
      cfg.preview_color=row.dataset.slug||slugify((row.querySelector('.msp-color-slug')||{}).value||(row.querySelector('.msp-color-name')||{}).value);
      cfg.side=side;load();syncHiddenConfig();
      persistBaseManagerAction('color',cfg.template,side,'add',url,row.dataset.slug,()=>hydrateRow(row));"""
j=replace_once(j,old,new,'JS_COLOR_ADD_V6')

old="""    row.dataset[side]='';const thumb=row.querySelectorAll('.msp-base-thumb')[side==='front'?0:1];if(thumb)thumb.style.backgroundImage='';
    rebuildColors();if(cfg.preview_color===row.dataset.slug)load();persistConfig('Base '+(side==='front'?'da frente':'do verso')+' removida.');"""
new="""    row.dataset[side]='';const thumb=row.querySelectorAll('.msp-base-thumb')[side==='front'?0:1];if(thumb)thumb.style.backgroundImage='';
    rebuildColors();if(cfg.preview_color===row.dataset.slug)load();syncHiddenConfig();
    persistBaseManagerAction('color',cfg.template,side,'remove','',row.dataset.slug,()=>hydrateRow(row));"""
j=replace_once(j,old,new,'JS_COLOR_REMOVE_V6')

# Navegação superior deixa de ser falsa: cada botão leva à área correspondente.
if 'MSP_TABS_NAV_V6' not in j:
    nav=r'''
// MSP_TABS_NAV_V6 — navegação visual, sem esconder dados nem causar perda de estado.
const mspTabTargets=['.msp-stage-card','.msp-controls','.msp-color-manager','.msp-products'];
document.querySelectorAll('.msp-tabs button').forEach((button,index)=>{
  button.onclick=()=>{
    document.querySelectorAll('.msp-tabs button').forEach(item=>item.classList.remove('active'));
    button.classList.add('active');
    const target=document.querySelector(mspTabTargets[index]||'.msp-stage-card');
    if(target)target.scrollIntoView({behavior:'smooth',block:'start'});
  };
});
'''
    j=j.replace("document.querySelectorAll('.msp-side-switch button').forEach",nav+"\ndocument.querySelectorAll('.msp-side-switch button').forEach",1)
    print('JS_TABS_NAV_V6=APPLIED')

# CSS profissional e responsivo. Mantém o painel funcional em vez de sobrepor remendos visuais.
if 'MSP_BASE_MANAGER_V6' not in c:
    c += r'''

/* MSP_BASE_MANAGER_V6 — layout profissional e controles claros */
.msp-app{--msp-border:#d9e1ea;--msp-text:#172033;--msp-muted:#667085;--msp-primary:#5b5bff;--msp-danger:#b42318;--msp-soft:#f8fafc}
.msp-tabs{position:sticky;top:32px;z-index:15;background:#fff;padding-top:4px}.msp-tabs button{cursor:pointer;font-weight:600}
.msp-grid{grid-template-columns:minmax(0,1fr) 360px!important;gap:16px!important;align-items:start}
.msp-stage-card{min-width:0}.msp-controls{min-width:0}.msp-products{grid-column:1/-1!important;display:grid!important;grid-template-columns:repeat(3,minmax(0,1fr))!important;gap:16px!important;padding:18px!important;border-color:var(--msp-border)!important;background:#fbfcfe!important}
.msp-products>h3{grid-column:1/-1;margin:0!important;font-size:18px!important;line-height:1.25;color:var(--msp-text)}
#msp_model_base_status{grid-column:1/-1}
.msp-base-manager-status{min-height:20px;padding:10px 12px;border:1px solid #e4e7ec;border-radius:8px;background:#fff;color:var(--msp-muted);font-weight:600}
.msp-base-manager-status:empty{display:none}.msp-base-manager-status.is-loading{display:block;background:#eff6ff;border-color:#bfdbfe;color:#1d4ed8}.msp-base-manager-status.is-success{display:block;background:#ecfdf3;border-color:#abefc6;color:#067647}.msp-base-manager-status.is-error{display:block;background:#fef3f2;border-color:#fecdca;color:#b42318}
.msp-product-card{min-width:0;padding:12px!important;border:1px solid var(--msp-border)!important;border-radius:12px!important;background:#fff!important;box-shadow:0 1px 2px rgba(16,24,40,.04)}
.msp-product-card.is-active{border-color:var(--msp-primary)!important;box-shadow:0 0 0 2px rgba(91,91,255,.12)!important}
.msp-product-card .msp-product{display:grid;grid-template-columns:64px minmax(0,1fr);gap:12px;min-height:76px;margin:0 0 12px!important;padding:8px!important;border:0!important;background:transparent!important;box-shadow:none!important;cursor:pointer}
.msp-product-card .msp-product img{width:64px!important;height:64px!important;background:#f6f7f9;border-radius:9px!important}.msp-product-card .msp-product span{font-size:14px;line-height:1.3}.msp-product-card .msp-product b{display:none!important}
.msp-model-base-grid{display:grid!important;grid-template-columns:1fr 1fr!important;gap:10px!important;padding-top:12px!important;border-top:1px solid #edf0f3!important}
.msp-model-base-side{position:relative;display:flex!important;flex-direction:column;gap:7px!important;min-width:0;padding:9px;border:1px solid #e4e7ec;border-radius:10px;background:var(--msp-soft)}
.msp-model-base-side>small{display:flex;align-items:center;justify-content:space-between;gap:6px;font-size:12px!important;color:#344054!important}
.msp-model-base-side>small:after{content:'Padrão';padding:2px 6px;border-radius:999px;background:#eef2f6;color:#475467;font-size:10px;font-weight:700}
.msp-model-base-side.has-custom-base>small:after{content:'Personalizada';background:#ecfdf3;color:#067647}.msp-model-base-side.is-base-removed>small:after{content:'Removida';background:#fef3f2;color:#b42318}
.msp-model-base-thumb{width:100%!important;height:132px!important;aspect-ratio:auto!important;background-color:#fff!important;border:1px solid #dde3ea!important;border-radius:9px!important}
.msp-model-base-side.is-base-removed .msp-model-base-thumb:after{font-size:12px!important;font-weight:600}
.msp-model-base-side .button{display:flex!important;align-items:center;justify-content:center;width:100%!important;min-height:34px!important;margin:0!important;padding:6px 9px!important;white-space:normal!important;font-weight:600}
.msp-model-base-side .button-link-delete{display:flex!important;align-items:center;justify-content:center;width:100%!important;min-height:32px!important;margin:0!important;padding:5px 8px!important;border:1px solid #fecdca!important;border-radius:6px!important;background:#fff!important;color:var(--msp-danger)!important;text-decoration:none!important;font-size:12px!important;font-weight:600!important;cursor:pointer!important}
.msp-model-base-side .button-link-delete:hover{background:#fef3f2!important}.msp-model-base-side .button-link-delete:disabled{opacity:.45!important;cursor:not-allowed!important}
.msp-custom{grid-column:1/-1!important;display:grid!important;grid-template-columns:minmax(0,1fr) 180px 180px;gap:10px!important;align-items:center;margin:2px 0 0!important;padding:14px!important;border:1px solid var(--msp-border)!important;border-radius:10px;background:#fff}
.msp-custom h4,.msp-custom p{grid-column:1;margin:0!important}.msp-custom .button{grid-row:1/3;width:100%!important;margin:0!important}.msp-custom .button[data-side=front]{grid-column:2}.msp-custom .button[data-side=back]{grid-column:3}
.msp-custom .button-link-delete{margin-top:6px!important}
.msp-color-manager{padding:20px!important}.msp-term-picker{margin-left:0!important}.msp-attribute-actions,.msp-sync-status{margin-left:0!important}.msp-color-terms-select{position:absolute!important;left:-9999px!important;width:1px!important;height:1px!important;overflow:hidden!important;opacity:0!important;pointer-events:none!important}
.msp-term-picker-head{margin-bottom:14px!important}.msp-term-options{gap:10px!important;padding:12px!important;border:1px solid #eaecf0!important;border-radius:10px;background:#fff!important}
.msp-term-option{flex:0 0 86px!important;min-height:84px!important;border-color:#eaecf0!important;background:#fff!important}.msp-term-option.is-selected{border-color:var(--msp-primary)!important;background:#f5f5ff!important;box-shadow:0 0 0 1px var(--msp-primary)!important}
.msp-color-table-wrap{margin-top:16px;border:1px solid #e4e7ec;border-radius:10px;overflow:auto!important}.msp-color-table{min-width:920px;border:0!important}.msp-color-table th{padding:12px!important;background:#f8fafc!important;font-weight:700}.msp-color-row td{padding:12px!important;background:#fff!important}.msp-color-table th:nth-child(1){width:230px!important}.msp-color-table th:nth-child(2),.msp-color-table th:nth-child(3){width:200px!important}.msp-base-thumb{width:140px!important;height:100px!important;margin:0 0 8px!important;background-color:#f8fafc!important}.msp-color-row td:nth-child(2) .button,.msp-color-row td:nth-child(3) .button{width:140px!important;margin-bottom:6px!important}.msp-color-row .msp-color-remove-base{display:block!important;width:140px!important;padding:4px 6px!important;border:1px solid #fecdca!important;border-radius:6px!important;background:#fff!important;color:var(--msp-danger)!important;text-align:center!important;text-decoration:none!important}
.msp-color-row .msp-remove-color{padding:7px 10px!important;border:1px solid #fecdca!important;border-radius:6px!important;background:#fff!important;color:var(--msp-danger)!important;text-decoration:none!important}
@media(max-width:1280px){.msp-products{grid-template-columns:repeat(2,minmax(0,1fr))!important}}
@media(max-width:980px){.msp-grid{grid-template-columns:1fr!important}.msp-products{grid-template-columns:1fr!important}.msp-custom{grid-template-columns:1fr 1fr!important}.msp-custom h4,.msp-custom p{grid-column:1/-1!important}.msp-custom .button{grid-row:auto!important}.msp-custom .button[data-side=front]{grid-column:1!important}.msp-custom .button[data-side=back]{grid-column:2!important}}
@media(max-width:600px){.msp-model-base-grid{grid-template-columns:1fr!important}.msp-custom{grid-template-columns:1fr!important}.msp-custom .button{grid-column:1!important}.msp-tabs{position:static;overflow-x:auto}.msp-tabs button{white-space:nowrap}}
'''
    print('CSS_BASE_MANAGER_V6=APPLIED')
else:
    print('CSS_BASE_MANAGER_V6=ALREADY_PRESENT')

php.write_text(p); js.write_text(j); css.write_text(c)
PY

chown belastock:belastock "$PHPFILE" "$JSFILE" "$CSSFILE"
chmod 0644 "$PHPFILE" "$JSFILE" "$CSSFILE"
php -l "$PHPFILE"
node --check "$JSFILE"
python3 - "$CSSFILE" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
assert 'MSP_BASE_MANAGER_V6' in s
assert s.count('{') == s.count('}'), (s.count('{'),s.count('}'))
print('CSS_BRACES=OK')
PY

grep -q 'wp_ajax_msp_base_manager_action' "$PHPFILE"
grep -q 'function ajax_base_manager_action' "$PHPFILE"
grep -q 'baseManagerNonce' "$PHPFILE"
grep -q 'persistBaseManagerAction' "$JSFILE"
grep -q 'MSP_BASE_MANAGER_V6' "$CSSFILE"

# Limpa caches transitórios e reinicia opcode PHP sem tocar em conteúdo.
sudo -u belastock -H wp --path="$DOCROOT" cache flush >/dev/null 2>&1 || true
systemctl reload php8.3-fpm 2>/dev/null || true

echo 'MSP_BASE_MANAGER_V6_FILES=OK'
