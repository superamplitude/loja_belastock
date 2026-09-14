<?php
if (!defined('ABSPATH')) exit;

/**
 * Hero Bela Stock V3.
 * Substitui o hero original do plugin por um carrossel Elementor editavel,
 * mantendo textos separados das imagens e permitindo adicionar/remover slides.
 */
add_action('elementor/widgets/register', static function ($widgets_manager): void {
    if (!class_exists('Elementor\\Widget_Base') || !class_exists('Elementor\\Controls_Manager') || !class_exists('Elementor\\Repeater')) {
        return;
    }

    if (method_exists($widgets_manager, 'unregister')) {
        $widgets_manager->unregister('belastock-hero');
    } elseif (method_exists($widgets_manager, 'unregister_widget_type')) {
        $widgets_manager->unregister_widget_type('belastock-hero');
    }

    if (!class_exists('BelaStock_Elementor_Hero_V3')) {
        class BelaStock_Elementor_Hero_V3 extends \Elementor\Widget_Base {
            public function get_name(): string { return 'belastock-hero'; }
            public function get_title(): string { return 'Bela Stock — Hero / Carrossel'; }
            public function get_icon(): string { return 'eicon-slider-full-screen'; }
            public function get_categories(): array { return ['belastock']; }

            protected function register_controls(): void {
                $this->start_controls_section('content', ['label' => 'Conteudo do hero']);
                $this->add_control('eyebrow', [
                    'label' => 'Linha superior',
                    'type' => \Elementor\Controls_Manager::TEXT,
                    'default' => 'Conforto • estilo • personalidade',
                ]);
                $this->add_control('title', [
                    'label' => 'Titulo',
                    'type' => \Elementor\Controls_Manager::TEXTAREA,
                    'default' => 'Vista sua melhor versao',
                ]);
                $this->add_control('text', [
                    'label' => 'Texto',
                    'type' => \Elementor\Controls_Manager::TEXTAREA,
                    'default' => 'Camisetas e acessorios para expressar quem voce e, com estampas que tem a sua personalidade.',
                ]);
                $this->add_control('button_text', [
                    'label' => 'Botao principal',
                    'type' => \Elementor\Controls_Manager::TEXT,
                    'default' => 'Personalize agora',
                ]);
                $this->add_control('button_link', [
                    'label' => 'Link principal',
                    'type' => \Elementor\Controls_Manager::URL,
                    'default' => ['url' => home_url('/loja/')],
                ]);
                $this->add_control('secondary_text', [
                    'label' => 'Botao secundario',
                    'type' => \Elementor\Controls_Manager::TEXT,
                    'default' => 'Ver colecao',
                ]);
                $this->add_control('secondary_link', [
                    'label' => 'Link secundario',
                    'type' => \Elementor\Controls_Manager::URL,
                    'default' => ['url' => home_url('/loja/')],
                ]);
                $this->end_controls_section();

                $this->start_controls_section('slides_section', ['label' => 'Imagens do carrossel']);
                $repeater = new \Elementor\Repeater();
                $repeater->add_control('image', [
                    'label' => 'Imagem',
                    'type' => \Elementor\Controls_Manager::MEDIA,
                ]);
                $repeater->add_control('alt', [
                    'label' => 'Descricao da imagem',
                    'type' => \Elementor\Controls_Manager::TEXT,
                    'default' => 'Modelo Bela Stock usando camiseta da marca',
                ]);
                $repeater->add_control('position', [
                    'label' => 'Posicao da imagem',
                    'type' => \Elementor\Controls_Manager::SELECT,
                    'default' => 'center center',
                    'options' => [
                        'center center' => 'Centro',
                        'right center' => 'Direita',
                        '70% center' => 'Direita suave',
                        '75% center' => 'Direita forte',
                        'left center' => 'Esquerda',
                    ],
                ]);
                $repeater->add_control('enabled', [
                    'label' => 'Exibir',
                    'type' => \Elementor\Controls_Manager::SWITCHER,
                    'return_value' => 'yes',
                    'default' => 'yes',
                ]);

                $this->add_control('slides', [
                    'label' => 'Slides — adicione, remova e reordene livremente',
                    'type' => \Elementor\Controls_Manager::REPEATER,
                    'fields' => $repeater->get_controls(),
                    'title_field' => '{{{ alt || "Imagem do hero" }}}',
                    'default' => [
                        ['image' => ['url' => 'https://belastock.com.br/assets/hero/hero-01.webp'], 'alt' => 'Modelo Bela Stock em fundo lilas claro — variacao 1', 'position' => 'center center', 'enabled' => 'yes'],
                        ['image' => ['url' => 'https://belastock.com.br/assets/hero/hero-02.webp'], 'alt' => 'Modelo Bela Stock em fundo lilas claro — variacao 2', 'position' => 'center center', 'enabled' => 'yes'],
                        ['image' => ['url' => 'https://belastock.com.br/assets/hero/hero-03.webp'], 'alt' => 'Modelo Bela Stock em fundo lilas claro — variacao 3', 'position' => 'center center', 'enabled' => 'yes'],
                        ['image' => ['url' => 'https://belastock.com.br/assets/hero/hero-04.webp'], 'alt' => 'Modelo Bela Stock em fundo lilas claro — variacao 4', 'position' => 'center center', 'enabled' => 'yes'],
                    ],
                ]);
                $this->add_control('autoplay_ms', [
                    'label' => 'Troca automatica (ms)',
                    'type' => \Elementor\Controls_Manager::NUMBER,
                    'min' => 2500,
                    'max' => 15000,
                    'step' => 500,
                    'default' => 6000,
                ]);
                $this->add_control('show_arrows', [
                    'label' => 'Mostrar setas',
                    'type' => \Elementor\Controls_Manager::SWITCHER,
                    'return_value' => 'yes',
                    'default' => 'yes',
                ]);
                $this->add_control('show_dots', [
                    'label' => 'Mostrar marcadores',
                    'type' => \Elementor\Controls_Manager::SWITCHER,
                    'return_value' => 'yes',
                    'default' => 'yes',
                ]);
                $this->end_controls_section();

                $this->start_controls_section('style', ['label' => 'Estilo', 'tab' => \Elementor\Controls_Manager::TAB_STYLE]);
                $this->add_control('accent', ['label' => 'Cor principal', 'type' => \Elementor\Controls_Manager::COLOR, 'default' => '#6f267e']);
                $this->add_control('title_color', ['label' => 'Cor do titulo', 'type' => \Elementor\Controls_Manager::COLOR, 'default' => '#3f164b']);
                $this->add_control('text_color', ['label' => 'Cor do texto', 'type' => \Elementor\Controls_Manager::COLOR, 'default' => '#4e3d53']);
                $this->add_control('overlay', [
                    'label' => 'Protecao de leitura do texto',
                    'type' => \Elementor\Controls_Manager::SLIDER,
                    'size_units' => ['%'],
                    'range' => ['%' => ['min' => 0, 'max' => 100, 'step' => 5]],
                    'default' => ['unit' => '%', 'size' => 38],
                ]);
                $this->add_responsive_control('hero_height', [
                    'label' => 'Altura do hero',
                    'type' => \Elementor\Controls_Manager::SLIDER,
                    'size_units' => ['px'],
                    'range' => ['px' => ['min' => 360, 'max' => 900, 'step' => 10]],
                    'default' => ['unit' => 'px', 'size' => 610],
                    'tablet_default' => ['unit' => 'px', 'size' => 540],
                    'mobile_default' => ['unit' => 'px', 'size' => 500],
                ]);
                $this->end_controls_section();
            }

            protected function render(): void {
                $s = $this->get_settings_for_display();
                $slides = [];
                foreach ((array)($s['slides'] ?? []) as $slide) {
                    if (($slide['enabled'] ?? 'yes') !== 'yes') continue;
                    $url = (string)($slide['image']['url'] ?? '');
                    if ($url === '') continue;
                    $slides[] = [
                        'url' => $url,
                        'alt' => (string)($slide['alt'] ?? 'Modelo Bela Stock'),
                        'position' => (string)($slide['position'] ?? 'center center'),
                    ];
                }
                if (!$slides) {
                    $slides[] = ['url' => 'https://belastock.com.br/assets/hero/hero-01.webp', 'alt' => 'Modelo Bela Stock', 'position' => 'center center'];
                }

                $id = 'bs-hero-v3-' . preg_replace('/[^a-zA-Z0-9_-]/', '', (string)$this->get_id());
                $delay = max(2500, min(15000, (int)($s['autoplay_ms'] ?? 6000)));
                $accent = (string)($s['accent'] ?? '#6f267e');
                $title_color = (string)($s['title_color'] ?? '#3f164b');
                $text_color = (string)($s['text_color'] ?? '#4e3d53');
                $overlay = max(0, min(100, (int)($s['overlay']['size'] ?? 38))) / 100;
                $height = max(360, min(900, (int)($s['hero_height']['size'] ?? 610)));
                $link = (string)($s['button_link']['url'] ?? home_url('/loja/'));
                $secondary = (string)($s['secondary_link']['url'] ?? home_url('/loja/'));

                echo '<section id="'.esc_attr($id).'" class="bs-v3-hero" data-delay="'.esc_attr((string)$delay).'" style="--bs-v3-accent:'.esc_attr($accent).';--bs-v3-title:'.esc_attr($title_color).';--bs-v3-text:'.esc_attr($text_color).';--bs-v3-overlay:'.esc_attr((string)$overlay).';--bs-v3-height:'.esc_attr((string)$height).'px">';
                echo '<div class="bs-v3-slides">';
                foreach ($slides as $i => $slide) {
                    echo '<figure class="bs-v3-slide'.($i === 0 ? ' is-active' : '').'" data-index="'.absint($i).'">';
                    echo '<img src="'.esc_url($slide['url']).'" alt="'.esc_attr($slide['alt']).'" style="object-position:'.esc_attr($slide['position']).'" '.($i === 0 ? 'fetchpriority="high"' : 'loading="lazy"').'>';
                    echo '</figure>';
                }
                echo '</div><div class="bs-v3-readable" aria-hidden="true"></div>';
                echo '<div class="bs-v3-copy">';
                if (!empty($s['eyebrow'])) echo '<span class="bs-v3-eyebrow">'.esc_html((string)$s['eyebrow']).'</span>';
                if (!empty($s['title'])) echo '<h1>'.nl2br(esc_html((string)$s['title'])).'</h1>';
                if (!empty($s['text'])) echo '<p>'.esc_html((string)$s['text']).'</p>';
                echo '<div class="bs-v3-actions">';
                if (!empty($s['button_text'])) echo '<a class="bs-v3-primary" href="'.esc_url($link).'">'.esc_html((string)$s['button_text']).'</a>';
                if (!empty($s['secondary_text'])) echo '<a class="bs-v3-secondary" href="'.esc_url($secondary).'">'.esc_html((string)$s['secondary_text']).'</a>';
                echo '</div></div>';

                if (count($slides) > 1 && (($s['show_arrows'] ?? 'yes') === 'yes')) {
                    echo '<button class="bs-v3-arrow bs-v3-prev" type="button" aria-label="Imagem anterior">&#8249;</button>';
                    echo '<button class="bs-v3-arrow bs-v3-next" type="button" aria-label="Proxima imagem">&#8250;</button>';
                }
                if (count($slides) > 1 && (($s['show_dots'] ?? 'yes') === 'yes')) {
                    echo '<div class="bs-v3-dots" aria-label="Navegacao do carrossel">';
                    foreach ($slides as $i => $_) echo '<button type="button" data-go="'.absint($i).'" class="'.($i === 0 ? 'is-active' : '').'" aria-label="Ir para imagem '.esc_attr((string)($i + 1)).'"></button>';
                    echo '</div>';
                }
                echo '</section>';

                echo '<style>
#'.esc_attr($id).'.bs-v3-hero{position:relative;min-height:var(--bs-v3-height);height:var(--bs-v3-height);overflow:hidden;background:#f2e8f7;isolation:isolate}
#'.esc_attr($id).' .bs-v3-slides,#'.esc_attr($id).' .bs-v3-slide{position:absolute;inset:0;margin:0}
#'.esc_attr($id).' .bs-v3-slide{opacity:0;transition:opacity .65s ease;z-index:0}
#'.esc_attr($id).' .bs-v3-slide.is-active{opacity:1;z-index:1}
#'.esc_attr($id).' .bs-v3-slide img{width:100%;height:100%;object-fit:cover;display:block}
#'.esc_attr($id).' .bs-v3-readable{position:absolute;inset:0;z-index:2;background:linear-gradient(90deg,rgba(255,255,255,var(--bs-v3-overlay)) 0%,rgba(255,255,255,calc(var(--bs-v3-overlay)*.82)) 29%,rgba(255,255,255,.16) 52%,rgba(255,255,255,0) 72%);pointer-events:none}
#'.esc_attr($id).' .bs-v3-copy{position:relative;z-index:3;width:min(620px,46vw);min-height:100%;display:flex;flex-direction:column;justify-content:center;padding:64px max(28px,calc((100vw - 1280px)/2));padding-right:24px}
#'.esc_attr($id).' .bs-v3-eyebrow{font-size:.76rem;text-transform:uppercase;letter-spacing:.12em;font-weight:900;color:var(--bs-v3-accent);margin-bottom:15px}
#'.esc_attr($id).' h1{margin:0;color:var(--bs-v3-title);font-size:clamp(2.8rem,5.4vw,5.8rem);line-height:.92;letter-spacing:-.055em;max-width:650px;text-wrap:balance}
#'.esc_attr($id).' p{max-width:520px;margin:20px 0 0;color:var(--bs-v3-text);font-size:1.03rem;line-height:1.62;font-weight:520}
#'.esc_attr($id).' .bs-v3-actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:24px}
#'.esc_attr($id).' .bs-v3-actions a{min-height:48px;padding:0 20px;border-radius:10px;display:inline-flex;align-items:center;justify-content:center;font-weight:900;font-size:.88rem;transition:transform .18s ease,box-shadow .18s ease}
#'.esc_attr($id).' .bs-v3-actions a:hover{transform:translateY(-1px)}
#'.esc_attr($id).' .bs-v3-primary{background:var(--bs-v3-accent);color:#fff!important;box-shadow:0 10px 28px rgba(78,28,91,.18)}
#'.esc_attr($id).' .bs-v3-secondary{background:rgba(255,255,255,.82);color:var(--bs-v3-title)!important;border:1px solid rgba(79,45,88,.18);backdrop-filter:blur(8px)}
#'.esc_attr($id).' .bs-v3-arrow{position:absolute;top:50%;transform:translateY(-50%);z-index:5;width:42px;height:42px;border:1px solid rgba(255,255,255,.55);border-radius:50%;background:rgba(58,27,65,.34);color:#fff;font-size:30px;line-height:1;cursor:pointer;backdrop-filter:blur(8px)}
#'.esc_attr($id).' .bs-v3-prev{left:16px}#'.esc_attr($id).' .bs-v3-next{right:16px}
#'.esc_attr($id).' .bs-v3-dots{position:absolute;z-index:5;left:50%;bottom:18px;transform:translateX(-50%);display:flex;gap:7px}
#'.esc_attr($id).' .bs-v3-dots button{width:8px;height:8px;padding:0;border:0;border-radius:999px;background:rgba(255,255,255,.6);box-shadow:0 0 0 1px rgba(63,22,75,.15);cursor:pointer;transition:width .2s ease,background .2s ease}
#'.esc_attr($id).' .bs-v3-dots button.is-active{width:25px;background:var(--bs-v3-accent)}
@media(max-width:900px){#'.esc_attr($id).'.bs-v3-hero{height:540px;min-height:540px}#'.esc_attr($id).' .bs-v3-copy{width:64vw;padding:44px 26px}#'.esc_attr($id).' h1{font-size:clamp(2.6rem,8vw,4.2rem)}#'.esc_attr($id).' .bs-v3-readable{background:linear-gradient(90deg,rgba(255,255,255,.88),rgba(255,255,255,.55) 48%,rgba(255,255,255,.03) 78%)}}
@media(max-width:620px){#'.esc_attr($id).'.bs-v3-hero{height:520px;min-height:520px}#'.esc_attr($id).' .bs-v3-copy{width:86vw;padding:34px 22px 62px}#'.esc_attr($id).' h1{font-size:3rem}#'.esc_attr($id).' p{font-size:.94rem;line-height:1.5}#'.esc_attr($id).' .bs-v3-readable{background:linear-gradient(90deg,rgba(255,255,255,.92),rgba(255,255,255,.68) 62%,rgba(255,255,255,.1))}#'.esc_attr($id).' .bs-v3-arrow{width:36px;height:36px;font-size:25px}#'.esc_attr($id).' .bs-v3-prev{left:8px}#'.esc_attr($id).' .bs-v3-next{right:8px}}
</style>';

                if (count($slides) > 1) {
                    $js_id = wp_json_encode($id);
                    echo '<script>(function(){const root=document.getElementById('.$js_id.');if(!root||root.dataset.bsV3Init)return;root.dataset.bsV3Init="1";const slides=[...root.querySelectorAll(".bs-v3-slide")],dots=[...root.querySelectorAll(".bs-v3-dots button")];let index=0,timer=null;const delay=parseInt(root.dataset.delay||"6000",10);const show=(n)=>{index=(n+slides.length)%slides.length;slides.forEach((s,i)=>s.classList.toggle("is-active",i===index));dots.forEach((d,i)=>d.classList.toggle("is-active",i===index));};const stop=()=>{if(timer){clearInterval(timer);timer=null;}};const start=()=>{stop();if(window.matchMedia("(prefers-reduced-motion: reduce)").matches)return;timer=setInterval(()=>show(index+1),delay);};root.querySelector(".bs-v3-prev")?.addEventListener("click",()=>{show(index-1);start();});root.querySelector(".bs-v3-next")?.addEventListener("click",()=>{show(index+1);start();});dots.forEach(d=>d.addEventListener("click",()=>{show(parseInt(d.dataset.go||"0",10));start();}));root.addEventListener("mouseenter",stop);root.addEventListener("mouseleave",start);root.addEventListener("focusin",stop);root.addEventListener("focusout",start);start();})();</script>';
                }
            }
        }
    }

    $widgets_manager->register(new BelaStock_Elementor_Hero_V3());
}, 40);
