#!/usr/bin/env bash
set -Eeuo pipefail

DOCROOT='/home/belastock/htdocs/loja.belastock.com.br'
PLUGIN="$DOCROOT/wp-content/plugins/mockup-studio-pro"
JSFILE="$PLUGIN/assets/js/editor.js"
CSSFILE="$PLUGIN/assets/css/admin.css"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/home/belastock/backups/mockup-studio-pro/admin-layout-v8-$STAMP"
mkdir -p "$BACKUP"
cp -a "$JSFILE" "$BACKUP/editor.js.before"
cp -a "$CSSFILE" "$BACKUP/admin.css.before"
echo "BACKUP=$BACKUP"

python3 - "$JSFILE" "$CSSFILE" <<'PY'
from pathlib import Path
import sys
js=Path(sys.argv[1]); css=Path(sys.argv[2])
j=js.read_text(); c=css.read_text()

CSS_MARK='/* MSP_ADMIN_LAYOUT_V8 */'
if CSS_MARK not in c:
    c += r'''

/* MSP_ADMIN_LAYOUT_V8 */
.msp-app{--v8-bg:#f7f8fb;--v8-card:#fff;--v8-line:#e5e7eb;--v8-text:#182230;--v8-muted:#667085;--v8-primary:#5b5bff;--v8-primary-soft:#f2f3ff;--v8-danger:#b42318}
.msp-app,.msp-app *{box-sizing:border-box}

/* topo enxuto */
.msp-admin-only{display:flex!important;align-items:center!important;gap:8px!important;margin:0 0 8px!important;padding:7px 10px!important;border:1px solid #dbe6f2!important;border-left:3px solid #2271b1!important;border-radius:8px!important;background:#f8fbff!important;color:#475467!important;font-size:12px!important;line-height:1.35!important}
.msp-admin-only .msp-version-badge{margin-left:auto!important;float:none!important;flex:0 0 auto!important}
.msp-product-mode{align-items:center!important;margin:0 0 10px!important;padding:10px 12px!important;border-radius:10px!important;background:#fff!important}
.msp-product-mode h2{margin:0!important;font-size:14px!important}.msp-product-mode p{display:none!important}
.msp-mockup-enable{padding:7px 10px!important;border-radius:8px!important;font-size:12px!important}

/* menu principal sem scroll interno; acompanha a página */
.msp-tabs{position:sticky!important;top:32px!important;z-index:60!important;display:grid!important;grid-template-columns:repeat(4,minmax(0,1fr))!important;gap:6px!important;margin:0 0 12px!important;padding:7px!important;border:1px solid #dfe3e8!important;border-radius:11px!important;background:rgba(255,255,255,.96)!important;box-shadow:0 6px 20px rgba(16,24,40,.08)!important;backdrop-filter:blur(10px);overflow:visible!important}
.msp-tabs button{min-width:0!important;margin:0!important;padding:9px 10px!important;border:1px solid transparent!important;border-radius:8px!important;background:transparent!important;color:#475467!important;font-size:12px!important;font-weight:700!important;line-height:1.2!important;white-space:normal!important;cursor:pointer!important}
.msp-tabs button:hover{background:#f7f8fa!important;color:#1d2939!important}.msp-tabs button.active{border-color:#d8d9ff!important;background:var(--v8-primary-soft)!important;color:#4545dd!important;box-shadow:none!important}

/* composição geral mais densa */
.msp-grid{grid-template-columns:minmax(0,1fr) 320px!important;gap:12px!important;align-items:start!important}
.msp-stage-card,.msp-panel,.msp-products,.msp-color-manager{border-color:var(--v8-line)!important;box-shadow:0 1px 3px rgba(16,24,40,.04)!important}
.msp-stage-card{min-height:0!important;padding:12px!important}.msp-controls{gap:8px!important}.msp-panel{padding:11px!important}.msp-panel h3{margin:0 0 8px!important;font-size:13px!important}
.msp-stage-actions{gap:6px!important;flex-wrap:wrap!important}.msp-stage-actions button{padding:7px 10px!important;font-size:12px!important}
.msp-range{grid-template-columns:68px 1fr 44px!important;gap:6px!important;margin:6px 0!important;font-size:12px!important}.msp-blend,.msp-composition-lock{font-size:12px!important}.msp-composition-lock{margin-top:8px!important;padding:8px!important}

/* produtos: seletor compacto + edição somente do modelo ativo */
.msp-products{grid-column:1/-1!important;display:block!important;margin-top:0!important;padding:14px!important;background:var(--v8-bg)!important}
.msp-products>h3{margin:0 0 9px!important;font-size:15px!important;color:var(--v8-text)!important}
.msp-base-manager-status{margin:0 0 10px!important;padding:8px 10px!important;font-size:12px!important}
.msp-model-picker-v8{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:7px;margin:0 0 10px}
.msp-model-picker-v8 button{appearance:none;display:flex;align-items:center;gap:8px;min-width:0;min-height:54px;padding:7px 8px;border:1px solid #dfe3e8;border-radius:9px;background:#fff;color:#1d2939;cursor:pointer;text-align:left;transition:.15s ease}
.msp-model-picker-v8 button:hover{border-color:#b8c1cc;background:#fcfcfd}.msp-model-picker-v8 button.is-active{border-color:var(--v8-primary);background:var(--v8-primary-soft);box-shadow:0 0 0 1px rgba(91,91,255,.12)}
.msp-model-picker-v8 img{width:38px;height:38px;flex:0 0 38px;object-fit:contain;border-radius:7px;background:#f4f5f7}.msp-model-picker-v8 span{min-width:0;font-size:11px;font-weight:700;line-height:1.2;overflow-wrap:anywhere}
.msp-active-model-title-v8{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:0 0 7px;padding:0 2px;color:#344054;font-size:12px}.msp-active-model-title-v8 strong{font-size:13px;color:#182230}.msp-active-model-title-v8 small{color:#667085}
.msp-products-v8 .msp-product-card{display:none!important;margin:0!important;padding:0!important;border:0!important;background:transparent!important;box-shadow:none!important}.msp-products-v8 .msp-product-card.is-active{display:block!important}.msp-products-v8 .msp-product-card>.msp-product{display:none!important}
.msp-products-v8 .msp-model-base-grid{display:grid!important;grid-template-columns:1fr 1fr!important;gap:9px!important;padding:0!important;border:0!important}
.msp-products-v8 .msp-model-base-side{display:grid!important;grid-template-columns:92px minmax(0,1fr) auto;grid-template-rows:auto auto;column-gap:10px!important;row-gap:5px!important;align-items:center!important;padding:9px!important;border:1px solid var(--v8-line)!important;border-radius:10px!important;background:#fff!important}
.msp-products-v8 .msp-model-base-thumb{grid-column:1;grid-row:1/3;width:92px!important;height:72px!important;margin:0!important;border-radius:8px!important;background-color:#f8fafc!important}
.msp-products-v8 .msp-model-base-side>small{grid-column:2;grid-row:1;margin:0!important;font-size:11px!important}.msp-products-v8 .msp-model-base-side>small:after{margin-left:6px!important;font-size:9px!important}
.msp-products-v8 .msp-model-base-side .button{grid-column:2;grid-row:2;width:auto!important;justify-self:start!important;min-height:29px!important;padding:4px 9px!important;font-size:11px!important}
.msp-products-v8 .msp-model-base-side .button-link-delete{grid-column:3;grid-row:1/3;width:auto!important;min-width:62px!important;min-height:29px!important;padding:4px 8px!important;border-radius:7px!important;font-size:10px!important}
.msp-custom{display:grid!important;grid-template-columns:minmax(0,1fr) auto auto!important;gap:8px!important;align-items:center!important;margin:10px 0 0!important;padding:9px 10px!important;border:1px dashed #d0d5dd!important;border-radius:9px!important;background:#fff!important}
.msp-custom h4{margin:0!important;font-size:12px!important}.msp-custom p{display:none!important}.msp-custom .button{grid-row:auto!important;width:auto!important;min-height:29px!important;margin:0!important;padding:4px 9px!important;font-size:11px!important}.msp-custom .button[data-side=front]{grid-column:2!important}.msp-custom .button[data-side=back]{grid-column:3!important}.msp-custom .button-link-delete{font-size:10px!important}

/* cores: menos texto e mais ação */
.msp-color-manager{margin-top:12px!important;padding:14px!important}.msp-color-head{align-items:center!important}.msp-color-head h2{margin:0!important;font-size:16px!important}.msp-color-head p{display:none!important}.msp-preview-status:empty{display:none!important}.msp-preview-status{margin:7px 0 0!important;padding:7px 9px!important;font-size:11px!important}
.msp-attribute-tools{margin:10px 0 0!important;padding:10px!important;border-radius:9px!important}.msp-attribute-field{display:grid!important;grid-template-columns:150px minmax(200px,360px)!important;gap:7px 10px!important;margin:0!important;font-size:12px!important}.msp-attribute-field small{display:none!important}
.msp-term-picker{margin:8px 0 0!important;padding:8px!important}.msp-term-picker-head{align-items:center!important;margin-bottom:7px!important}.msp-term-picker-head small{display:none!important}.msp-term-picker-head strong{font-size:12px!important}.msp-term-picker-actions .button{min-height:28px!important;padding:3px 8px!important;font-size:11px!important}
.msp-term-options{gap:7px!important;padding:8px!important}.msp-term-option{flex:0 0 68px!important;min-height:69px!important;padding:6px 4px!important}.msp-term-option .msp-picker-swatch{width:31px!important;height:31px!important;flex-basis:31px!important}.msp-term-option .msp-term-label{font-size:10px!important}.msp-term-check{width:16px!important;height:16px!important;line-height:16px!important;font-size:9px!important}
.msp-sync-options{display:flex!important;flex-direction:row!important;align-items:center!important;gap:8px!important;margin-top:7px!important;padding:7px 9px!important;font-size:11px!important}.msp-sync-options small{display:none!important}.msp-attribute-actions{margin:7px 0 0!important}.msp-attribute-actions .button{min-height:30px!important;font-size:11px!important}.msp-sync-status{min-height:0!important;margin:5px 0 0!important;font-size:11px!important}.msp-sync-status:empty{display:none!important}
.msp-color-table-wrap{margin-top:10px!important}.msp-color-table th{padding:8px!important;font-size:11px!important}.msp-color-row td{padding:8px!important}.msp-base-thumb{width:104px!important;height:76px!important;margin-bottom:5px!important}.msp-color-row td:nth-child(2) .button,.msp-color-row td:nth-child(3) .button,.msp-color-row .msp-color-remove-base{width:104px!important;font-size:10px!important}.msp-color-copy strong{font-size:12px!important}.msp-color-copy small{display:none!important}.msp-inline-color{margin-top:2px!important;font-size:10px!important}

/* remove rolagem horizontal do menu em qualquer breakpoint */
@media(max-width:1280px){.msp-model-picker-v8{grid-template-columns:repeat(3,minmax(0,1fr))}.msp-products-v8 .msp-model-base-grid{grid-template-columns:1fr!important}}
@media(max-width:980px){.msp-grid{grid-template-columns:1fr!important}.msp-model-picker-v8{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media(max-width:782px){.msp-tabs{top:46px!important;grid-template-columns:repeat(2,minmax(0,1fr))!important;overflow:visible!important}.msp-tabs button{white-space:normal!important}.msp-model-picker-v8{grid-template-columns:repeat(2,minmax(0,1fr))}.msp-products-v8 .msp-model-base-side{grid-template-columns:78px minmax(0,1fr);grid-template-rows:auto auto auto}.msp-products-v8 .msp-model-base-thumb{width:78px!important;height:66px!important}.msp-products-v8 .msp-model-base-side .button-link-delete{grid-column:2;grid-row:3;justify-self:start!important}.msp-custom{grid-template-columns:1fr 1fr!important}.msp-custom h4{grid-column:1/-1!important}.msp-custom .button[data-side=front]{grid-column:1!important}.msp-custom .button[data-side=back]{grid-column:2!important}.msp-attribute-field{grid-template-columns:1fr!important}}
@media(max-width:520px){.msp-model-picker-v8{grid-template-columns:1fr 1fr}.msp-model-picker-v8 button{min-height:48px}.msp-model-picker-v8 img{width:32px;height:32px;flex-basis:32px}.msp-products-v8 .msp-model-base-grid{grid-template-columns:1fr!important}.msp-color-head{display:block!important}.msp-color-head-actions{margin-top:7px!important;justify-content:flex-start!important}}
'''
    print('CSS_LAYOUT_V8=APPLIED')
else:
    print('CSS_LAYOUT_V8=ALREADY_PRESENT')

JS_MARK='// MSP_ADMIN_LAYOUT_V8'
if JS_MARK not in j:
    j += r'''

// MSP_ADMIN_LAYOUT_V8
(function(){
  const app=document.querySelector('.msp-app');
  const products=document.querySelector('.msp-products');
  const tabs=[...document.querySelectorAll('.msp-tabs button')];
  if(!app||!products)return;

  products.classList.add('msp-products-v8');
  const cards=[...products.querySelectorAll('.msp-product-card[data-template]')];

  // Modelos como seletor compacto. Mantemos os botões originais no DOM para preservar toda a lógica existente.
  if(cards.length&&!products.querySelector('.msp-model-picker-v8')){
    const picker=document.createElement('div');
    picker.className='msp-model-picker-v8';
    picker.setAttribute('role','tablist');
    picker.setAttribute('aria-label','Modelos de produto');

    cards.forEach(card=>{
      const original=card.querySelector('.msp-product[data-template]');
      if(!original)return;
      const button=document.createElement('button');
      button.type='button';
      button.dataset.template=original.dataset.template||card.dataset.template||'';
      button.setAttribute('role','tab');
      const img=original.querySelector('img');
      const label=original.querySelector('span');
      const cloneImg=document.createElement('img');
      if(img&&img.getAttribute('src'))cloneImg.src=img.getAttribute('src');
      cloneImg.alt='';
      const text=document.createElement('span');
      text.textContent=label?label.textContent.trim():button.dataset.template;
      button.append(cloneImg,text);
      button.addEventListener('click',()=>{
        original.click();
        requestAnimationFrame(syncModelPicker);
      });
      picker.appendChild(button);
    });

    const title=document.createElement('div');
    title.className='msp-active-model-title-v8';
    title.innerHTML='<strong>Base do modelo selecionado</strong><small>Frente e costas</small>';
    const anchor=products.querySelector('#msp_model_base_status')||products.querySelector('h3');
    if(anchor){anchor.insertAdjacentElement('afterend',picker);picker.insertAdjacentElement('afterend',title);}else{products.prepend(title);products.prepend(picker);}

    function syncModelPicker(){
      cards.forEach(card=>{
        const key=card.dataset.template||'';
        const original=card.querySelector('.msp-product[data-template]');
        const button=picker.querySelector('button[data-template="'+CSS.escape(key)+'"]');
        if(!button||!original)return;
        const active=card.classList.contains('is-active')||original.classList.contains('active');
        button.classList.toggle('is-active',active);
        button.setAttribute('aria-selected',active?'true':'false');
        const source=original.querySelector('img');
        const target=button.querySelector('img');
        if(target&&source){
          const src=source.getAttribute('src')||'';
          if(src)target.src=src; else target.removeAttribute('src');
          target.style.visibility=source.style.visibility||'';
        }
        if(active){
          const label=original.querySelector('span');
          const strong=title.querySelector('strong');
          if(strong)strong.textContent='Base — '+(label?label.textContent.trim():key);
        }
      });
    }
    cards.forEach(card=>new MutationObserver(syncModelPicker).observe(card,{subtree:true,attributes:true,attributeFilter:['class','src','style']}));
    syncModelPicker();
  }

  // Rótulos menores e objetivos.
  const labels=['Mockup','Arte','Cores','Bases'];
  tabs.forEach((button,index)=>{if(labels[index])button.textContent=labels[index];});

  // Menu acompanha a rolagem e indica a seção em uso sem criar barra de scroll própria.
  const sections=[
    document.querySelector('.msp-stage-card'),
    document.querySelector('.msp-controls'),
    document.querySelector('.msp-color-manager'),
    document.querySelector('.msp-products')
  ];
  let ticking=false;
  function updateActiveTab(){
    ticking=false;
    const stickyOffset=(window.innerWidth<=782?100:82);
    let best=0,bestDistance=Infinity;
    sections.forEach((section,index)=>{
      if(!section)return;
      const rect=section.getBoundingClientRect();
      const distance=Math.abs(rect.top-stickyOffset);
      if(rect.bottom>stickyOffset&&distance<bestDistance){best=index;bestDistance=distance;}
    });
    tabs.forEach((button,index)=>button.classList.toggle('active',index===best));
  }
  window.addEventListener('scroll',()=>{if(!ticking){ticking=true;requestAnimationFrame(updateActiveTab);}},{passive:true});
  window.addEventListener('resize',updateActiveTab,{passive:true});
  updateActiveTab();
})();
'''
    print('JS_LAYOUT_V8=APPLIED')
else:
    print('JS_LAYOUT_V8=ALREADY_PRESENT')

js.write_text(j); css.write_text(c)
PY

node --check "$JSFILE"
php -l "$PLUGIN/includes/class-msp-plugin.php"
grep -q 'MSP_ADMIN_LAYOUT_V8' "$JSFILE"
grep -q 'MSP_ADMIN_LAYOUT_V8' "$CSSFILE"
grep -q 'position:sticky!important' "$CSSFILE"
grep -q 'overflow:visible!important' "$CSSFILE"
grep -q 'msp-model-picker-v8' "$JSFILE"

# Limpa cache de objeto/transientes sem tocar em produto, catálogo ou configuração do plugin.
sudo -u belastock -H wp --path="$DOCROOT" cache flush >/dev/null 2>&1 || true

printf 'MSP_LAYOUT_V8=OK\n'
printf 'MSP_MENU_STICKY_NO_SCROLL=OK\n'
printf 'MSP_COMPACT_MODEL_EDITOR=OK\n'
printf 'MSP_COMPACT_COLOR_MANAGER=OK\n'
