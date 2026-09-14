#!/usr/bin/env bash
set -Eeuo pipefail
DOCROOT='/home/belastock/htdocs/loja.belastock.com.br'
PLUGIN="$DOCROOT/wp-content/plugins/mockup-studio-pro"
PHPFILE="$PLUGIN/includes/class-msp-plugin.php"
JSFILE="$PLUGIN/assets/js/editor.js"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/home/belastock/backups/mockup-studio-pro/base-manager-$STAMP"

test -f "$PHPFILE"
test -f "$JSFILE"
mkdir -p "$BACKUP"
cp -a "$PHPFILE" "$BACKUP/class-msp-plugin.php.before"
cp -a "$JSFILE" "$BACKUP/editor.js.before"
echo "BACKUP=$BACKUP"

python3 - "$PHPFILE" "$JSFILE" <<'PY'
from pathlib import Path
import sys
php = Path(sys.argv[1]); js = Path(sys.argv[2])
p = php.read_text(); j = js.read_text()

def rep(text, old, new, label):
    if new in text:
        print(f'{label}=ALREADY_PRESENT'); return text
    if old not in text:
        raise SystemExit(f'PATCH_ABORT:{label}')
    print(f'{label}=APPLIED'); return text.replace(old,new,1)

# PHP: AJAX save endpoint + nonce.
old="        add_action('wp_ajax_msp_sync_variations', [$this, 'ajax_sync_variations']);"
new=old+"\n        add_action('wp_ajax_msp_save_config', [$this, 'ajax_save_config']);"
p=rep(p,old,new,'PHP_AJAX_SAVE_HOOK')
old="            'syncNonce'=>wp_create_nonce('msp_sync_variations_'.$post_id),"
new=old+"\n            'saveNonce'=>wp_create_nonce('msp_save_config_'.$post_id),"
p=rep(p,old,new,'PHP_SAVE_NONCE')

marker="    public function ajax_sync_variations(): void {"
method=r'''    public function ajax_save_config(): void {
        $post_id = absint($_POST['post_id'] ?? 0);
        check_ajax_referer('msp_save_config_'.$post_id, 'nonce');
        if (!$post_id || !current_user_can('edit_post', $post_id)) {
            wp_send_json_error(['message'=>'Permissão inválida.'], 403);
        }
        $posted = json_decode(wp_unslash($_POST['config'] ?? '{}'), true);
        if (!is_array($posted)) wp_send_json_error(['message'=>'Configuração inválida.'], 400);
        $current = get_post_meta($post_id, '_msp_config', true);
        if (!is_array($current)) $current = [];
        if (!array_key_exists('enabled', $posted)) $posted['enabled'] = $this->is_mockup_enabled($current);
        $clean = $this->clean_config($posted);
        update_post_meta($post_id, '_msp_config', $clean);
        update_post_meta($post_id, '_bpp_publication_mode', !empty($clean['enabled']) ? 'mockup' : 'ready');
        $taxonomy = sanitize_key((string) ($clean['color_attribute'] ?? ''));
        if (strpos($taxonomy, 'pa_') === 0 && taxonomy_exists($taxonomy)) {
            foreach ((array) ($clean['color_bases'] ?? []) as $slug => $row) {
                $term_id = absint($row['term_id'] ?? 0);
                if (!$term_id) {
                    $term = get_term_by('slug', sanitize_title((string) $slug), $taxonomy);
                    $term_id = ($term && !is_wp_error($term)) ? (int) $term->term_id : 0;
                }
                if (!$term_id) continue;
                update_term_meta($term_id, '_msp_swatch_color', sanitize_hex_color((string) ($row['color'] ?? '')) ?: $this->fallback_swatch_color((string) $slug));
                if (array_key_exists('image', $row)) update_term_meta($term_id, '_msp_swatch_image', esc_url_raw((string) $row['image']));
            }
        }
        wp_send_json_success(['message'=>'Bases do mockup salvas.']);
    }

'''
if 'public function ajax_save_config(): void {' not in p:
    if marker not in p: raise SystemExit('PATCH_ABORT:PHP_SAVE_METHOD')
    p=p.replace(marker,method+marker,1); print('PHP_SAVE_METHOD=APPLIED')
else: print('PHP_SAVE_METHOD=ALREADY_PRESENT')

old="        if (!$colors) wp_send_json_error(['message'=>'Selecione pelo menos uma cor.']);\n\n        $product = wc_get_product($post_id);"
new="        if (!$colors) wp_send_json_error(['message'=>'Selecione pelo menos uma cor.']);\n\n        $current_config['enabled'] = true;\n        $current_config['color_attribute'] = $attribute;\n        $current_config['color_bases'] = $posted_bases;\n        $current_config = $this->clean_config($current_config);\n        update_post_meta($post_id, '_msp_config', $current_config);\n        update_post_meta($post_id, '_bpp_publication_mode', 'mockup');\n\n        $product = wc_get_product($post_id);"
p=rep(p,old,new,'PHP_SYNC_PERSISTS_BASES')

# JS: safe media + immediate persistence + remove controls.
old="""function media(cb){
  const f=wp.media({title:MSP_DATA.i18n.choose,button:{text:MSP_DATA.i18n.use},multiple:false});
  f.on('select',()=>cb(f.state().get('selection').first().toJSON().url));
  f.open();
}"""
new="""function media(cb){
  if(typeof wp==='undefined'||!wp.media){setSyncStatus('A Biblioteca de Mídia não está disponível nesta tela.','error');return;}
  const f=wp.media({title:MSP_DATA.i18n.choose,button:{text:MSP_DATA.i18n.use},library:{type:'image'},multiple:false});
  f.on('select',()=>{const item=f.state().get('selection').first();if(item)cb(item.toJSON().url);});
  f.open();
}
function persistConfig(message='Bases salvas.'){
  sync();
  if(!MSP_DATA.postId||!MSP_DATA.saveNonce)return;
  $.post(MSP_DATA.ajaxUrl,{action:'msp_save_config',nonce:MSP_DATA.saveNonce,post_id:MSP_DATA.postId,config:JSON.stringify(cfg)})
    .done(resp=>{if(resp&&resp.success){if(message)setSyncStatus(message,'success');}else setSyncStatus(resp&&resp.data&&resp.data.message?resp.data.message:'Não foi possível salvar as bases.','error');})
    .fail(()=>setSyncStatus('Erro de comunicação ao salvar as bases.','error'));
}
function decorateBaseControls(scope=document){
  scope.querySelectorAll('.msp-color-upload').forEach(button=>{
    const side=button.dataset.side,cell=button.closest('td');
    if(!cell||cell.querySelector('.msp-color-remove-base[data-side="'+side+'"]'))return;
    const remove=document.createElement('button');
    remove.type='button';remove.className='button-link-delete msp-color-remove-base';remove.dataset.side=side;
    remove.textContent=side==='front'?'Remover frente':'Remover verso';button.insertAdjacentElement('afterend',remove);
  });
  scope.querySelectorAll('.msp-upload-base').forEach(button=>{
    const side=button.dataset.side;
    if(button.parentElement&&button.parentElement.querySelector('.msp-remove-base[data-side="'+side+'"]'))return;
    const remove=document.createElement('button');
    remove.type='button';remove.className='button-link-delete msp-remove-base';remove.dataset.side=side;
    remove.textContent=side==='front'?'Remover base da frente':'Remover base do verso';button.insertAdjacentElement('afterend',remove);
  });
}"""
j=rep(j,old,new,'JS_MEDIA_PERSIST_HELPERS')

old="""    `<td><div class="msp-base-thumb"></div><button type="button" class="button msp-color-upload" data-side="front">Selecionar frente</button></td>`+
    `<td><div class="msp-base-thumb"></div><button type="button" class="button msp-color-upload" data-side="back">Selecionar verso</button></td>`+"""
new="""    `<td><div class="msp-base-thumb"></div><button type="button" class="button msp-color-upload" data-side="front">Selecionar frente</button> <button type="button" class="button-link-delete msp-color-remove-base" data-side="front">Remover frente</button></td>`+
    `<td><div class="msp-base-thumb"></div><button type="button" class="button msp-color-upload" data-side="back">Selecionar verso</button> <button type="button" class="button-link-delete msp-color-remove-base" data-side="back">Remover verso</button></td>`+"""
j=rep(j,old,new,'JS_ROW_REMOVE_BUTTONS')

old="""setupAttributes();
document.querySelectorAll('.msp-color-row').forEach(row=>hydrateRow(row));
refreshAttributeUi(true);"""
new="""setupAttributes();
document.querySelectorAll('.msp-color-row').forEach(row=>hydrateRow(row));
refreshAttributeUi(true);
decorateBaseControls(document);
setTimeout(()=>{if(isGlobalAttribute()&&termSelect&&termSelect.selectedOptions.length)applyTermSelection(false);decorateBaseControls(document);},50);"""
j=rep(j,old,new,'JS_ATTRIBUTE_ROWS_BOOTSTRAP')

old="""  rebuildColors();
  if(showMessage){
    setSyncStatus(selected.size+' cor(es) selecionada(s). Clique em uma cor para adicionar ou remover; não é necessário digitar nada.','success');
  }"""
new="""  rebuildColors();
  decorateBaseControls(rowsContainer);
  if(showMessage){
    setSyncStatus(selected.size+' cor(es) selecionada(s). Clique em uma cor para adicionar ou remover; não é necessário digitar nada.','success');
    persistConfig('Cores e bases atualizadas.');
  }"""
j=rep(j,old,new,'JS_TERM_SELECTION_PERSIST')

old="""  if(upload){
    const side=upload.dataset.side;
    media(url=>{
      row.dataset[side]=url;
      row.querySelectorAll('.msp-base-thumb')[side==='front'?0:1].style.backgroundImage=`url("${url}")`;
      rebuildColors();
      cfg.preview_color=row.dataset.slug||slugify((row.querySelector('.msp-color-slug')||{}).value||(row.querySelector('.msp-color-name')||{}).value);
      cfg.side=side;
      load();
    });
  }else if(event.target.closest('.msp-remove-color')){"""
new="""  if(upload){
    const side=upload.dataset.side;
    media(url=>{
      row.dataset[side]=url;
      row.querySelectorAll('.msp-base-thumb')[side==='front'?0:1].style.backgroundImage=`url("${url}")`;
      rebuildColors();
      cfg.preview_color=row.dataset.slug||slugify((row.querySelector('.msp-color-slug')||{}).value||(row.querySelector('.msp-color-name')||{}).value);
      cfg.side=side;load();persistConfig('Base '+(side==='front'?'da frente':'do verso')+' salva para este atributo.');
    });
  }else if(event.target.closest('.msp-color-remove-base')){
    const removeBase=event.target.closest('.msp-color-remove-base'),side=removeBase.dataset.side;
    row.dataset[side]='';const thumb=row.querySelectorAll('.msp-base-thumb')[side==='front'?0:1];if(thumb)thumb.style.backgroundImage='';
    rebuildColors();if(cfg.preview_color===row.dataset.slug)load();persistConfig('Base '+(side==='front'?'da frente':'do verso')+' removida.');
  }else if(event.target.closest('.msp-remove-color')){"""
j=rep(j,old,new,'JS_COLOR_BASE_ADD_REMOVE')

old="""    row.remove();
    rebuildColors();
    load();
  }else if(event.target.closest('.msp-preview-color')){"""
new="""    row.remove();
    rebuildColors();
    load();
    persistConfig('Cor removida das bases deste produto.');
  }else if(event.target.closest('.msp-preview-color')){"""
j=rep(j,old,new,'JS_REMOVE_COLOR_PERSIST')

old="""  const field=lastRow.querySelector('.msp-color-name');
  if(field&&field.type!=='hidden')field.focus();
};"""
new="""  decorateBaseControls(lastRow);
  const field=lastRow.querySelector('.msp-color-name');
  if(field&&field.type!=='hidden')field.focus();
};"""
j=rep(j,old,new,'JS_LOCAL_ROW_DECORATE')

old="""document.querySelectorAll('.msp-upload-base').forEach(button=>button.onclick=()=>media(url=>{
  cfg[button.dataset.side+'_base']=url;cfg.preview_color='';cfg.side=button.dataset.side;load();
}));"""
new="""document.querySelectorAll('.msp-upload-base').forEach(button=>button.onclick=()=>media(url=>{
  cfg[button.dataset.side+'_base']=url;cfg.preview_color='';cfg.side=button.dataset.side;load();
  persistConfig('Base padrão '+(button.dataset.side==='front'?'da frente':'do verso')+' salva.');
}));
document.addEventListener('click',event=>{
  const button=event.target.closest('.msp-remove-base');if(!button)return;
  const side=button.dataset.side;cfg[side+'_base']='';if(cfg.preview_color==='')cfg.side=side;load();
  persistConfig('Base padrão '+(side==='front'?'da frente':'do verso')+' removida.');
});
decorateBaseControls(document);"""
j=rep(j,old,new,'JS_DEFAULT_BASE_ADD_REMOVE')

php.write_text(p); js.write_text(j)
PY

chown belastock:belastock "$PHPFILE" "$JSFILE"
chmod 0644 "$PHPFILE" "$JSFILE"
php8.3 -l "$PHPFILE"
node --check "$JSFILE"
grep -q 'wp_ajax_msp_save_config' "$PHPFILE"
grep -q 'public function ajax_save_config' "$PHPFILE"
grep -q 'msp-color-remove-base' "$JSFILE"
grep -q 'msp-remove-base' "$JSFILE"
grep -q 'persistConfig' "$JSFILE"
systemctl reload php8.3-fpm || systemctl restart php8.3-fpm
sudo -u belastock -H wp --path="$DOCROOT" core is-installed
LOGIN_CODE="$(curl -kLsS --max-redirs 5 --max-time 20 --resolve 'loja.belastock.com.br:443:127.0.0.1' -o /dev/null -w '%{http_code}' 'https://loja.belastock.com.br/wp-login.php')"
echo "WP_LOGIN_HTTP=$LOGIN_CODE"
test "$LOGIN_CODE" = 200
echo 'MSP_BASE_DELETE=OK'
echo 'MSP_BASE_ADD=OK'
echo 'MSP_ATTRIBUTE_BASE_MAPPING=OK'
echo 'MSP_CONFIG_IMMEDIATE_SAVE=OK'
echo 'MSP_BASE_MANAGER_FIX=100%_OK'
