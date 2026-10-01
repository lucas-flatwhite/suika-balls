#!/usr/bin/env python3
"""Idempotent localized, safe-area-aware shell around a fresh Godot export."""

import argparse
import base64
import html
import hashlib
import io
import json
import os
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
START = '<!-- mushies:managed-head:start -->'
END = '<!-- mushies:managed-head:end -->'
LOADER_START = '<!-- mushies:loader:start -->'
LOADER_END = '<!-- mushies:loader:end -->'


def replace_once(source: str, pattern: str, replacement: str, label: str) -> str:
    source, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'Could not find the Godot {label} hook in the export.')
    return source


def patch_godot_loader(source: str) -> str:
    # These hook only Godot's generated status code and tolerate a prior managed pass.
    # Observe slow engine-script transfer before its blocking request starts.
    source = re.sub(r'<script data-mushies-startup>.*?</script>\s*', '', source, flags=re.S)
    def early_start(match):
        engine_script = match[1].replace(' onerror="window.MushiesLoader?.failure()"', '')
        engine_script = engine_script.replace('<script', '<script onerror="window.MushiesLoader?.failure()"', 1)
        return '<script data-mushies-startup>window.MushiesLoader?.begin();</script>\n' + engine_script + match[3]
    source, count = re.subn(
        r'(<script\b[^>]*\bsrc=(["\'])[^"\']+\2[^>]*>\s*</script>\s*)(<script\b[^>]*>\s*const GODOT_CONFIG)',
        early_start, source, count=1,
    )
    if count != 1:
        raise RuntimeError('Could not find the Godot engine-script startup hook in the export.')
    source = replace_once(
        source,
        r'function setStatusMode\(mode\) \{.*?(?=\n\s*function setStatusNotice)',
        r"""function setStatusMode(mode) {
        if (statusMode === mode || !initializing) {
            return;
        }
        if (mode === 'hidden') {
            // The engine is ready; briefly finish the final bounded duck drop.
            statusMode = mode;
            const finished = window.MushiesLoader?.ready();
            Promise.resolve(finished).then((completed) => {
                if (completed === false || !initializing || statusMode !== 'hidden') return;
                statusOverlay.remove();
                initializing = false;
            });
            return;
        }
        statusOverlay.style.visibility = 'visible';
        // The custom shell owns visible progress and player-facing errors.
        statusProgress.style.display = 'none';
        statusNotice.style.display = 'none';
        statusMode = mode;
    }""",
        'setStatusMode',
    )
    source = replace_once(
        source,
        r'function displayFailureNotice\(err\) \{.*?(?=\n\s*const missing)',
        r"""function displayFailureNotice(err) {
        // Preserve the technical diagnostic while giving players a clear recovery.
        console.error(err);
        statusOverlay.style.visibility = 'visible';
        setStatusNotice(t('loader.error'));
        setStatusMode('notice');
        window.MushiesLoader?.failure();
        initializing = false;
    }""",
        'displayFailureNotice',
    )
    source = replace_once(
        source,
        r"setStatusMode\('progress'\);\s*(?:window\.MushiesLoader\?\.(?:begin|scriptReady)\(\);\s*)?engine\.startGame\(\{\s*'onProgress': function \(current, total\) \{.*?\n\s*\},\s*\}\)\.then\(\(\) => \{\s*.*?\}, displayFailureNotice\);",
        r"""setStatusMode('progress');
            window.MushiesLoader?.scriptReady();
            engine.startGame({
                'onProgress': function (current, total) {
                    // Godot reports bytes when known; unknown totals remain indeterminate.
                    window.MushiesLoader?.progress(current, total);
                },
            }).then(() => {
                // A completed transfer still prepares the engine; never fake ready.
                setStatusMode('hidden');
            }, displayFailureNotice);""",
        'onProgress',
    )
    return source


def font_styles(copy: dict, encode=None) -> str:
    """Embed one loader face covering only loader glyphs; runtime fonts stay unchanged."""
    characters = ''.join(str(value) for entries in copy.values() for value in entries.values())
    # The rotation guard also owns a localized message outside the dictionaries.
    # Include non-ASCII source literals so those glyphs survive every rebuild.
    for relative in ('ui/mobile/runtime.js', 'ui/mobile/loader.js'):
        source = (ROOT / relative).read_text()
        source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
        source = re.sub(r'\\u\{([0-9a-fA-F]+)\}|\\u([0-9a-fA-F]{4})',
                        lambda match: chr(int(match[1] or match[2], 16)), source)
        characters += ''.join(char for char in source if ord(char) > 127)
    wanted = {ord(char) for char in characters if not char.isspace()} | set(range(0x20, 0x7f))
    if encode is None:
        cached = (ROOT / 'ui/web/loader-fonts.css').read_text()
        metadata = json.loads((ROOT / 'ui/web/loader-fonts.json').read_text())
        if hashlib.sha256(cached.encode()).hexdigest() != metadata['sha256']:
            raise RuntimeError('Cached loader font bytes changed; rebuild from pinned loader sources')
        missing = wanted - set(metadata['codepoints'])
        if missing:
            raise RuntimeError('Cached loader fonts lack new characters; rebuild from pinned loader sources: ' + repr(sorted(missing)))
        return cached
    # Maintenance passes the shared encoder for the approved runtime face
    # (scripts/build-game-loader-fonts.py); it verifies source bytes and coverage.
    data = base64.b64encode(encode(wanted)).decode('ascii')
    return '@font-face{font-family:"Noto Sans SC";font-style:normal;font-weight:400 700;font-display:swap;src:url(data:font/woff2;base64,' + data + ') format("woff2")}'


def render_shell(source: str, installable: bool = True, loader_image=None) -> str:
    # Replace an earlier managed head regardless of the title used by that export.
    source = re.sub(
        r'<!-- (?P<brand>[a-z][a-z0-9-]*):managed-head:start -->.*?<!-- (?P=brand):managed-head:end -->',
        '',
        source,
        flags=re.S,
    )
    source = re.sub(r'<div id="rotate-hint".*?</div></div>', '', source, flags=re.S)
    source = re.sub(r'<meta name="viewport"[^>]*>', '', source)
    source = re.sub(r'<a id="sound-lab-link".*?</a>', '', source, flags=re.S)
    source = re.sub(r'<!-- mushies:mobile:start -->.*?<!-- mushies:mobile:end -->', '', source, flags=re.S)
    source = re.sub(r'<!-- mushies:loader:start -->.*?<!-- mushies:loader:end -->', '', source, flags=re.S)
    source = source.replace("        document.getElementById('loading-label')?.remove();\n", '')
    dictionaries = {
        locale: json.loads((ROOT / 'localization' / f'{locale}.json').read_text()) for locale in ('en', 'zh_CN')
    }
    ui = {
        locale: {
            key: value
            for key, value in entries.items()
            if key.startswith(('loader.', 'mobile.')) or key in ('app.title', 'app.tagline')
        }
        for locale, entries in dictionaries.items()
    }
    # The cached loader face covers the template copy; Korean loader text uses the
    # device's Korean system font through the CSS fallback list below.
    font_css = font_styles(ui)
    # Game locales: Korean (default) and English, matching localization/ko.json and en.json.
    def loader_copy(name):
        entries = json.loads((ROOT / 'localization' / f'{name}.json').read_text())
        return {key: value for key, value in entries.items() if key.startswith(('loader.', 'mobile.')) or key in ('app.title', 'app.tagline')}
    ui = {'ko': loader_copy('ko'), 'en': loader_copy('en')}
    mobile_css = (ROOT / 'ui/mobile/runtime.css').read_text()
    mobile_js = (ROOT / 'ui/mobile/runtime.js').read_text()
    loader_css = (ROOT / 'ui/mobile/loader.css').read_text()
    loader_js = (ROOT / 'ui/mobile/loader.js').read_text()
    endpoint = os.environ.get('MANUS_ANALYTICS_ENDPOINT', '').strip().rstrip('/')
    website = os.environ.get('MANUS_ANALYTICS_WEBSITE_ID', '').strip()
    tracker = '<!-- Manus analytics pending provisioning -->'
    if endpoint and website:
        tracker = f'<script defer src="{html.escape(endpoint, quote=True)}/script.js" data-website-id="{html.escape(website, quote=True)}"></script>'
    source = re.sub(r'<title>.*?</title>', '<title>비치볼 머지 · Beach Ball Merge</title>', source, flags=re.S)
    head = f"""{START}
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="manus-game-loading-screen" content="1">
<meta name="theme-color" content="#7fd6f2">
<meta name="description" content="비치볼 머지: 같은 스포츠 공 2개를 붙여 더 큰 공으로! 해변에서 즐기는 물리 합체 퍼즐. Beach Ball Merge: merge matching sports balls on the beach.">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="비치볼 머지">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<link rel="manifest" href="mushies.webmanifest">
<link rel="preload" href="loader-duck.webp" as="image" type="image/webp">
<!-- Embedded font: Noto Sans SC loader subset (SIL Open Font License 1.1).
License text: assets/template/fonts/NotoSansSC-OFL.txt; the export's Open Source Licenses page lists it.
-->
<style>
{font_css}
html,body {{ margin:0; width:100%; height:100%; overflow:hidden; background:#bfeaf7; font-family:"Noto Sans SC","Apple SD Gothic Neo","Malgun Gothic","Noto Sans KR",sans-serif; }}
#canvas {{ position:fixed; left:env(safe-area-inset-left); top:env(safe-area-inset-top); width:calc(100% - env(safe-area-inset-left) - env(safe-area-inset-right)) !important; height:calc(100% - env(safe-area-inset-top) - env(safe-area-inset-bottom)) !important; display:block; outline:none; touch-action:none; }}
#status {{ background:#bfeaf7; color:#593c49; font:64px/1.6 "Noto Sans SC";font-synthesis:none; }}
#status-splash {{ max-width:192px; object-fit:contain; }}
{mobile_css}
{loader_css}
</style>
<script>
const PLUSHIE_COPY={json.dumps(ui, ensure_ascii=False)};
let plushieLocale = String((navigator.languages && navigator.languages[0]) || navigator.language || '').toLowerCase().startsWith('ko') ? 'ko' : 'en';
try {{ const saved = localStorage.getItem('plushie_locale'); if(saved in PLUSHIE_COPY) plushieLocale=saved; }} catch {{}}
function t(key, placeholders={{}}) {{ let value=PLUSHIE_COPY[plushieLocale][key] ?? PLUSHIE_COPY.ko[key] ?? key; for(const [name,text] of Object.entries(placeholders)) value=value.replaceAll('{{'+name+'}}',String(text)); return value; }}
document.documentElement.lang=plushieLocale;
document.title=t('app.title');
window.mushiesSetLocale = locale => {{
 if (locale in PLUSHIE_COPY) plushieLocale=locale;
 document.title=t('app.title');
 document.documentElement.lang=plushieLocale;
 for (const [id,key] of Object.entries({{'portrait-title':'mobile.rotate_title','portrait-body':'mobile.rotate_body','portrait-action':'mobile.enter_portrait'}})) {{
  const node=document.getElementById(id); if(node) node.textContent=t(key);
 }}
 document.getElementById('canvas')?.setAttribute('aria-label',t('app.title'));
 window.MushiesLoader?.refresh();
}};
document.addEventListener('DOMContentLoaded',()=>{{
 window.mushiesSetLocale(plushieLocale);
 document.querySelector('#canvas').setAttribute('aria-label',t('app.title'));
}});
{mobile_js}
{loader_js}
</script>
{tracker}
{END}"""
    source = re.sub(r'\s*</head>', '\n</head>', source)
    source = source.replace('</head>', head + '\n</head>', 1)
    source = re.sub(r'[ \t]*<canvas', '<canvas', source)
    guard = '<!-- mushies:mobile:start --><section id="portrait-guard" role="dialog" aria-modal="true" aria-labelledby="portrait-title" hidden><div><h1 id="portrait-title"></h1><p id="portrait-body"></p><button id="portrait-action" type="button"></button></div></section><!-- mushies:mobile:end -->'
    source = source.replace('<canvas', guard + '\n<canvas', 1)
    loader = f"""{LOADER_START}<section id="mushies-loader" role="status" aria-live="polite" aria-atomic="true" hidden><div id="mushies-loader-ducks" aria-hidden="true"></div><div id="mushies-loader-card"><h1 id="mushies-loader-message"></h1><p id="mushies-loader-detail" hidden></p><div id="mushies-loader-progress" role="progressbar"></div><button id="mushies-loader-retry" type="button" hidden></button></div></section>{LOADER_END}"""
    source = re.sub(r'\s*(<img\b[^>]*\bid="status-splash"[^>]*>)', r'\n\1', source, count=1)
    source, count = re.subn(
        r'(<img\b[^>]*\bid="status-splash"[^>]*>)', lambda match: loader + '\n' + match.group(1), source, count=1
    )
    if count != 1:
        raise RuntimeError('Could not find the Godot status splash hook in the export.')
    source = source.replace(
        'Your browser does not support the canvas tag.',
        ui['en']['loader.no_canvas'],
    )
    source = source.replace(
        'Your browser does not support JavaScript.', ui['en']['loader.no_js']
    )
    source = patch_godot_loader(source)
    if not installable:
        source = source.replace('<link rel="manifest" href="mushies.webmanifest">', '')
        duck = 'data:image/webp;base64,' + base64.b64encode(
            loader_image if loader_image is not None else
            (ROOT / 'assets/ui/loader-ball.webp').read_bytes()
        ).decode('ascii')
        source = source.replace('loader-duck.webp', duck)
    return '\n'.join(line.rstrip() for line in source.splitlines() if line.strip()) + '\n'


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', default='web')
    args = parser.parse_args()
    index = ROOT / args.directory / 'index.html'
    index.write_text(render_shell(index.read_text()))
    shutil.copyfile(ROOT / 'assets/ui/loader-ball.webp', index.parent / 'loader-duck.webp')
    icons = []
    for size in (192, 512):
        name = f'app-icon-{size}.png'
        shutil.copyfile(ROOT / 'assets/template/ui' / name, index.parent / name)
        icons.append({'src': name, 'sizes': f'{size}x{size}', 'type': 'image/png'})
    (index.parent / 'mushies.webmanifest').write_text(
        json.dumps(
            {
                'name': '비치볼 머지',
                'short_name': '비치볼 머지',
                'start_url': './',
                'display': 'fullscreen',
                'orientation': 'portrait',
                'background_color': '#f5e8de',
                'theme_color': '#f5e8de',
                'icons': icons,
            },
            indent=2,
        )
        + '\n'
    )
    # Clean only the retired generated review route; original audio/source is retained.
    retired = index.parent / 'sfx'
    if retired.is_dir():
        shutil.rmtree(retired)
    print('Prepared localized Mushies shell:', index)


if __name__ == '__main__':
    main()
