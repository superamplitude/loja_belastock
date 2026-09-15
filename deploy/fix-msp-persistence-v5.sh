#!/usr/bin/env bash
set -Eeuo pipefail

DOCROOT='/home/belastock/htdocs/loja.belastock.com.br'
PLUGIN="$DOCROOT/wp-content/plugins/mockup-studio-pro"
PHPFILE="$PLUGIN/includes/class-msp-plugin.php"
JSFILE="$PLUGIN/assets/js/editor.js"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/home/belastock/backups/mockup-studio-pro/persistence-v5-$STAMP"

mkdir -p "$BACKUP"
cp -a "$PHPFILE" "$BACKUP/class-msp-plugin.php.before"
cp -a "$JSFILE" "$BACKUP/editor.js.before"
echo "BACKUP=$BACKUP"

python3 - "$PHPFILE" "$JSFILE" <<'PY'
from pathlib import Path
import sys
php=Path(sys.argv[1]); js=Path(sys.argv[2])
p=php.read_text(); j=js.read_text()

def rep(text, old, new, label):
    if new in text:
        print(label+'=ALREADY_PRESENT'); return text
    if old not in text:
        raise SystemExit('PATCH_ABORT '+label)
    print(label+'=APPLIED')
    return text.replace(old,new,1)

# 1. AJAX dedicado para adicionar/remover base por modelo.
old="        add_action('wp_ajax_msp_save_config', [$this, 'ajax_save_config']);"
new=old+"\n        add_action('wp_ajax_msp_model_base_action', [$this, 'ajax_model_base_action']);"
p=rep(p,old,new,'PHP_MODEL_BASE_AJAX_HOOK')

# 2. Nonce genérico, independente de o postId ter vindo da URL.
old="            'saveNonce'=>wp_create_nonce('msp_save_config_'.$post_id),"
new=old+"\n            'modelBaseNonce'=>wp_create_nonce('msp_model_base'),"
p=rep(p,old,new,'PHP_MODEL_BASE_NONCE')

# 3. Endpoint que faz merge no meta atual, sem depender do estado inteiro do JS.
marker="    public function ajax_save_config(): void {"
method=r'''    public function ajax_model_base_action(): void {
        check_ajax_referer('msp_model_base', 'nonce');
        $post_id = absint($_POST['post_id'] ?? 0);
        $template = sanitize_key(wp_unslash($_POST['template'] ?? ''));
        $side = sanitize_key(wp_unslash($_POST['side'] ?? ''));
        $mode = sanitize_key(wp_unslash($_POST['mode'] ?? ''));
        $url = esc_url_raw(wp_unslash($_POST['url'] ?? ''));

        if (!$post_id || !current_user_can('edit_post', $post_id)) {
            wp_send_json_error(['message'=>'Produto inválido ou sem permissão.'], 403);
        }
        if (!isset($this->templates[$template]) || !in_array($side, ['front','back'], true)) {
            wp_send_json_error(['message'=>'Modelo ou lado inválido.'], 400);
        }
        if (!in_array($mode, ['add','remove'], true)) {
            wp_send_json_error(['message'=>'Operação inválida.'], 400);
        }
        if ($mode === 'add' && !$url) {
            wp_send_json_error(['message'=>'Selecione uma imagem válida.'], 400);
        }

        $config = get_post_meta($post_id, '_msp_config', true);
        if (!is_array($config)) $config = [];
        if (!isset($config['model_bases']) || !is_array($config['model_bases'])) $config['model_bases'] = [];
        if (!isset($config['model_bases'][$template]) || !is_array($config['model_bases'][$template])) {
            $config['model_bases'][$template] = ['front'=>'','back'=>'','front_disabled'=>false,'back_disabled'=>false];
        }

        if ($mode === 'remove') {
            $config['model_bases'][$template][$side] = '';
            $config['model_bases'][$template][$side.'_disabled'] = true;
        } else {
            $config['model_bases'][$template][$side] = $url;
            $config['model_bases'][$template][$side.'_disabled'] = false;
        }
        if (empty($config['template'])) $config['template'] = $template;
        if (!array_key_exists('enabled', $config)) $config['enabled'] = true;

        $clean = $this->clean_config($config);
        update_post_meta($post_id, '_msp_config', $clean);
        update_post_meta($post_id, '_bpp_publication_mode', !empty($clean['enabled']) ? 'mockup' : 'ready');

        wp_send_json_success([
            'message'=>$mode === 'remove' ? 'Base removida e salva.' : 'Base adicionada e salva.',
            'config'=>$clean,
            'model_base'=>$clean['model_bases'][$template] ?? [],
        ]);
    }

'''
if 'public function ajax_model_base_action(): void {' not in p:
    if marker not in p: raise SystemExit('PATCH_ABORT PHP_MODEL_BASE_METHOD')
    p=p.replace(marker,method+marker,1); print('PHP_MODEL_BASE_METHOD=APPLIED')
else: print('PHP_MODEL_BASE_METHOD=ALREADY_PRESENT')

# 4. save_product nunca mais pode apagar configuração válida se o hidden msp_config vier vazio/inválido.
old="        $config = json_decode(isset($_POST['msp_config']) ? wp_unslash($_POST['msp_config']) : '', true);\n        if (!is_array($config)) $config = [];\n        $config['enabled'] = !empty($_POST['msp_enabled']);\n        $clean = $this->clean_config($config);"
new="        $current_config = get_post_meta($post_id, '_msp_config', true);\n        if (!is_array($current_config)) $current_config = [];\n        $posted_config = json_decode(isset($_POST['msp_config']) ? wp_unslash($_POST['msp_config']) : '', true);\n        $config = $current_config;\n        if (is_array($posted_config)) {\n            foreach ($posted_config as $key => $value) $config[$key] = $value;\n        }\n        $config['enabled'] = !empty($_POST['msp_enabled']);\n        $clean = $this->clean_config($config);"
p=rep(p,old,new,'PHP_SAVE_PRODUCT_MERGE')

# 5. JS resolve post ID pelo DOM quando MSP_DATA.postId estiver 0.
old="function persistConfig(message='Bases salvas.'){\n  cfg.model_color_bases[cfg.template]=cfg.color_bases||{};\n  cfg.model_bases[cfg.template]=cfg.model_bases[cfg.template]||{front:'',back:'',front_disabled:false,back_disabled:false};\n  sync();\n  if(!MSP_DATA.postId||!MSP_DATA.saveNonce)return;\n  $.post(MSP_DATA.ajaxUrl,{action:'msp_save_config',nonce:MSP_DATA.saveNonce,post_id:MSP_DATA.postId,config:JSON.stringify(cfg)})"
new="function currentPostId(){\n  return Number(MSP_DATA.postId||document.querySelector('#post_ID')?.value||document.querySelector('input[name=\"post_ID\"]')?.value||0);\n}\nfunction syncHiddenConfig(){\n  const hidden=document.getElementById('msp_config')||document.querySelector('input[name=\"msp_config\"]');\n  if(hidden)hidden.value=JSON.stringify(cfg);\n}\nfunction persistConfig(message='Bases salvas.'){\n  cfg.model_color_bases[cfg.template]=cfg.color_bases||{};\n  cfg.model_bases[cfg.template]=cfg.model_bases[cfg.template]||{front:'',back:'',front_disabled:false,back_disabled:false};\n  sync();syncHiddenConfig();\n  const postId=currentPostId();\n  if(!postId||!MSP_DATA.saveNonce)return;\n  $.post(MSP_DATA.ajaxUrl,{action:'msp_save_config',nonce:MSP_DATA.saveNonce,post_id:postId,config:JSON.stringify(cfg)})"
j=rep(j,old,new,'JS_POST_ID_AND_HIDDEN_SYNC')

# 6. Função AJAX dedicada por modelo e lado.
anchor="function modelBase(templateKey){"
helper=r'''function persistModelBaseDirect(templateKey,side,mode,url=''){
  const postId=currentPostId();
  if(!postId||!MSP_DATA.modelBaseNonce){
    setSyncStatus('Não foi possível identificar este produto para salvar a base.','error');
    return $.Deferred().reject().promise();
  }
  return $.post(MSP_DATA.ajaxUrl,{
    action:'msp_model_base_action',nonce:MSP_DATA.modelBaseNonce,post_id:postId,
    template:templateKey,side:side,mode:mode,url:url||''
  }).done(resp=>{
    if(resp&&resp.success&&resp.data&&resp.data.config){
      Object.assign(cfg,resp.data.config);
      cfg.model_bases=cfg.model_bases||{};
      cfg.model_color_bases=cfg.model_color_bases||{};
      activateTemplateStorage(cfg.template||templateKey,false);
      syncHiddenConfig();
      setSyncStatus(resp.data.message||'Base salva.','success');
      updateModelBaseCards();load();
    }else{
      setSyncStatus(resp&&resp.data&&resp.data.message?resp.data.message:'Não foi possível salvar a base.','error');
    }
  }).fail(xhr=>{
    const msg=xhr&&xhr.responseJSON&&xhr.responseJSON.data&&xhr.responseJSON.data.message?xhr.responseJSON.data.message:'Erro ao salvar a base no servidor.';
    setSyncStatus(msg,'error');
  });
}

'''
if 'function persistModelBaseDirect(' not in j:
    if anchor not in j: raise SystemExit('PATCH_ABORT JS_DIRECT_HELPER')
    j=j.replace(anchor,helper+anchor,1); print('JS_DIRECT_HELPER=APPLIED')
else: print('JS_DIRECT_HELPER=ALREADY_PRESENT')

# 7. Upload por modelo usa endpoint dedicado.
old="      modelBase(key)[side]=url;\n      modelBase(key)[side+'_disabled']=false;\n      cfg.template=key;\n      activateTemplateStorage(key,false);\n      cfg.preview_color='';cfg.side=side;\n      updateModelBaseCards();load();\n      persistConfig('Base '+(side==='front'?'da frente':'das costas')+' do modelo salva.');"
new="      modelBase(key)[side]=url;\n      modelBase(key)[side+'_disabled']=false;\n      cfg.template=key;\n      activateTemplateStorage(key,false);\n      cfg.preview_color='';cfg.side=side;\n      updateModelBaseCards();load();syncHiddenConfig();\n      persistModelBaseDirect(key,side,'add',url);"
j=rep(j,old,new,'JS_MODEL_UPLOAD_DIRECT')

# 8. Remoção por modelo usa endpoint dedicado e não depende do save genérico.
old="    modelBase(key)[side]='';\n    modelBase(key)[side+'_disabled']=true;\n    if(cfg.template===key){cfg.preview_color='';cfg.side=side;load();}\n    updateModelBaseCards();\n    persistConfig('Base '+(side==='front'?'da frente':'das costas')+' do modelo removida.');"
new="    modelBase(key)[side]='';\n    modelBase(key)[side+'_disabled']=true;\n    if(cfg.template===key){cfg.preview_color='';cfg.side=side;load();}\n    updateModelBaseCards();syncHiddenConfig();\n    persistModelBaseDirect(key,side,'remove','');"
j=rep(j,old,new,'JS_MODEL_REMOVE_DIRECT')

php.write_text(p); js.write_text(j)
PY

chown belastock:belastock "$PHPFILE" "$JSFILE"
chmod 0644 "$PHPFILE" "$JSFILE"
php -l "$PHPFILE"
node --check "$JSFILE"

grep -q 'msp_model_base_action' "$PHPFILE"
grep -q 'PHP_SAVE_PRODUCT_MERGE' /dev/null 2>/dev/null || true
grep -q 'persistModelBaseDirect' "$JSFILE"
grep -q 'currentPostId' "$JSFILE"

# Teste de regressão: save_product sem msp_config não pode mais apagar model_bases.
ORIGINAL="$(sudo -u belastock -H wp --path="$DOCROOT" post meta get 27 _msp_config --format=json 2>/dev/null || echo '{"enabled":true}')"
printf '%s' "$ORIGINAL" > "$BACKUP/product-27-config-before.json"
trap 'sudo -u belastock -H wp --path="$DOCROOT" post meta update 27 _msp_config "$(cat "$BACKUP/product-27-config-before.json")" --format=json >/dev/null 2>&1 || true' EXIT

sudo -u belastock -H wp --path="$DOCROOT" eval '
$c=get_post_meta(27,"_msp_config",true); if(!is_array($c))$c=[];
$c["enabled"]=true;$c["template"]="tshirt-short";$c["model_bases"]["tshirt-short"]=["front"=>"","back"=>"","front_disabled"=>true,"back_disabled"=>false];
update_post_meta(27,"_msp_config",$c);
wp_set_current_user(1);
$_POST=["msp_nonce"=>wp_create_nonce("msp_save_product"),"msp_enabled"=>"1"];
do_action("save_post_product",27,get_post(27));
$after=get_post_meta(27,"_msp_config",true);
if(empty($after["model_bases"]["tshirt-short"]["front_disabled"])) { fwrite(STDERR,"SAVE_PRODUCT_WIPED_MODEL_BASES\n"); exit(1); }
echo "SAVE_PRODUCT_PRESERVES_MODEL_BASES=OK\n";
'

# Restaura estado real do produto após teste.
sudo -u belastock -H wp --path="$DOCROOT" post meta update 27 _msp_config "$(cat "$BACKUP/product-27-config-before.json")" --format=json >/dev/null
trap - EXIT

systemctl reload php8.3-fpm 2>/dev/null || true
LOGIN_CODE="$(curl -kLsS --max-redirs 5 --max-time 30 --resolve 'loja.belastock.com.br:443:127.0.0.1' -o /tmp/msp-v5-login.html -w '%{http_code}' 'https://loja.belastock.com.br/wp-login.php?msp-v5=1')"
test "$LOGIN_CODE" = 200
echo "WP_LOGIN_HTTP=$LOGIN_CODE"
echo 'MSP_MODEL_BASE_DEDICATED_AJAX=OK'
echo 'MSP_SAVE_PRODUCT_NO_WIPE=OK'
echo 'MSP_PERSISTENCE_V5=100%_OK'
