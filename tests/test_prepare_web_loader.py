#!/usr/bin/env python3
"""Self-contained regression test for the managed Godot loader shell; no committed export is read."""

import base64
import importlib.util
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
TOOLS = REPO / 'tools'
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location('prepare_web_under_test', TOOLS / 'prepare_web.py')
prepare_web = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare_web)

FRESH_GODOT_INDEX = """<!doctype html><html><head><meta charset="utf-8"><title>Fresh Export</title></head><body>
<canvas id="canvas">Your browser does not support the canvas tag.</canvas><noscript>Your browser does not support JavaScript.</noscript>
<div id="status"><img id="status-splash" src="index.png" alt=""><progress id="status-progress"></progress><div id="status-notice"></div></div>
<script src="index.js"></script>
<script>const GODOT_CONFIG = {}; const GODOT_THREADS_ENABLED = false; const engine = new Engine(GODOT_CONFIG);
(function () {
 const statusOverlay = document.getElementById('status'); const statusProgress = document.getElementById('status-progress'); const statusNotice = document.getElementById('status-notice'); let initializing = true; let statusMode = '';
 function setStatusMode(mode) { if (statusMode === mode || !initializing) { return; } if (mode === 'hidden') { statusOverlay.remove(); initializing = false; return; } statusOverlay.style.visibility = 'visible'; statusProgress.style.display = mode === 'progress' ? 'block' : 'none'; statusNotice.style.display = mode === 'notice' ? 'block' : 'none'; statusMode = mode; }
 function setStatusNotice(text) { statusNotice.textContent = text; }
 function displayFailureNotice(err) { console.error(err); setStatusNotice(err.message); setStatusMode('notice'); initializing = false; }
 const missing = Engine.getMissingFeatures({threads: GODOT_THREADS_ENABLED});
 if (missing.length !== 0) { displayFailureNotice(new Error('missing')); } else {
 setStatusMode('progress');
 engine.startGame({
  'onProgress': function (current, total) {
   if (current > 0 && total > 0) { statusProgress.value = current; statusProgress.max = total; } else { statusProgress.removeAttribute('value'); statusProgress.removeAttribute('max'); }
  },
 }).then(() => {
  setStatusMode('hidden');
 }, displayFailureNotice);
}
}());</script></body></html>"""

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    (root / 'web').mkdir()
    (root / 'localization').mkdir()
    (root / 'ui/mobile').mkdir(parents=True)
    (root / 'ui/web').mkdir(parents=True)
    for name in ('loader-fonts.css', 'loader-fonts.json'):
        shutil.copy2(REPO / 'ui/web' / name, root / 'ui/web' / name)
    (root / 'assets/template/ui').mkdir(parents=True)
    for locale in ('en', 'zh_CN'):
        catalogue = json.loads((REPO / 'localization' / f'{locale}.json').read_text())
        (root / 'localization' / f'{locale}.json').write_text(json.dumps(catalogue))
    for name in ('runtime.js', 'runtime.css', 'loader.js', 'loader.css'):
        shutil.copy2(REPO / 'ui/mobile' / name, root / 'ui/mobile' / name)
    for size in (192, 512):
        (root / 'assets/template/ui' / f'app-icon-{size}.png').write_bytes(b'fixture icon')
    duck = root / 'assets/template/plushies/runtime/chick.webp'
    duck.parent.mkdir(parents=True)
    shutil.copy2(REPO / 'assets/template/plushies/runtime/chick.webp', duck)
    shutil.copytree(REPO / 'assets/template/fonts', root / 'assets/template/fonts')
    index = root / 'web/index.html'
    index.write_text(FRESH_GODOT_INDEX)
    prepare_web.ROOT = root
    (root / 'web/sfx').mkdir()
    (root / 'web/sfx/index.html').write_text('retired review page')
    original_argv = sys.argv
    try:
        sys.argv = ['prepare_web.py', '--directory', 'web']
        prepare_web.main()
        first = index.read_text()
        prepare_web.main()
        second = index.read_text()
    finally:
        sys.argv = original_argv

    assert not (root / 'web/sfx').exists(), 'Retired Sound Lab output must be removed'
    assert 'sound-lab-link' not in second and 'ui.sound_lab' not in second
    assert first.count('@font-face{font-family:"Noto Sans SC"') == 1 and 'ManusCC0' not in first
    assert 'font:16px/1.4 "Noto Sans SC"' in first
    assert first == second, 'An installable export must postprocess byte-identically on repeat.'
    assert first.count('mushies:managed-head:start') == 1
    assert first.count('mushies:loader:start') == 1
    assert first.count('id="mushies-loader"') == 1
    assert 'id="mushies-loader-ducks" aria-hidden="true"' in first
    assert 'href="loader-duck.webp" as="image"' in first
    assert 'id="mushies-loader-title"' not in first and 'id="mushies-loader-mascot"' not in first
    assert 'id="mushies-loader-bar"' not in first
    assert 'LOADING...' in first and '加载中…' in first
    assert 'role="progressbar"' in first and 'aria-live="polite"' in first
    assert 'window.MushiesLoader?.progress(current, total);' in first
    assert 'window.MushiesLoader?.begin();' in first
    assert first.index('<script data-mushies-startup>') < first.index('src="index.js"')
    assert 'onerror="window.MushiesLoader?.failure()"' in first
    assert first.count('<script data-mushies-startup>') == 1
    assert 'window.MushiesLoader?.scriptReady();' in first
    assert 'window.MushiesLoader?.ready();' in first
    assert 'Promise.resolve(finished).then' in first
    assert "completed === false || !initializing || statusMode !== 'hidden'" in first
    assert 'window.MushiesLoader?.failure();' in first
    assert 'statusProgress.value = current' not in first, 'Stock progress must not compete with the custom progress UI.'
    assert 'console.error(err);' in first, 'Godot diagnostics must remain in the console.'
    assert 'loader.progress_label' in first and 'loader.retry' in first
    assert (root / 'web/app-icon-192.png').read_bytes() == b'fixture icon'
    assert (root / 'web/loader-duck.webp').read_bytes() == duck.read_bytes()
    assert json.loads((root / 'web/mushies.webmanifest').read_text())['name'] == 'Mushies'
    subprocess.run(['node', str(REPO / 'tests/test_loader_handoff.js'), str(index)], check=True)

    managed = prepare_web.render_shell(FRESH_GODOT_INDEX, installable=False)
    assert prepare_web.render_shell(managed, installable=False) == managed, (
        'Managed shell generation must be idempotent.'
    )
    assert prepare_web.render_shell(first, installable=False) == managed, (
        'Installable output must convert to the same managed shell.'
    )
    assert '<meta name="manus-game-loading-screen" content="1">' in managed
    assert '<link rel="manifest"' not in managed
    assert 'loader-duck.webp' not in managed, 'Managed exports must not depend on a separately copied duck image.'
    embedded = re.search(r"duck\.src\s*=\s*(['\"])(data:image/webp;base64,([^'\"]+))\1", managed)
    assert embedded, 'Managed duck sprites must use an embedded WebP.'
    assert base64.b64decode(embedded.group(3), validate=True) == duck.read_bytes(), (
        'Managed sprites must retain the original duck bytes.'
    )
    assert f'href="{embedded.group(2)}" as="image" type="image/webp"' in managed, (
        'Managed image preload must use the same embedded duck.'
    )
    managed_index = root / 'web/managed.html'
    managed_index.write_text(managed)
    subprocess.run(['node', str(REPO / 'tests/test_loader_handoff.js'), str(managed_index)], check=True)

    restored = prepare_web.render_shell(managed, installable=True)
    assert restored == first, 'Managed output must convert back to the same installable shell.'
    assert prepare_web.render_shell(restored, installable=True) == restored, (
        'Converted installable output must remain idempotent.'
    )
    assert 'data:image/webp;base64,' not in restored, 'Installable conversion must discard the managed duck data URL.'

print(
    'PASS: fresh installable/managed loaders preserve duck assets, accessibility, diagnostics, awaited handoff and two-way idempotence.'
)
