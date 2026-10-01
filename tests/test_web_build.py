#!/usr/bin/env python3
"""Validate current Web artifacts, localized shell and pack inclusion/exclusion."""
import hashlib,json,re,struct,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
WEB=ROOT/'web'
source=(WEB/'index.html').read_text()
assert 'mushies:managed-head:start' in source
assert 'PLUSHIE_COPY' in source and 'zh_CN' in source
assert 'rotate-hint' not in source and 'Make room for cuddles' not in source
assert 'env(safe-area-inset-left)' in source
assert 'font:64px/1.6' in source,'Desktop loader font is doubled again with the native UI'
assert 'sound-lab-link' not in source and 'ui.sound_lab' not in source,'Sound Lab must not be linked or embedded'
assert not (WEB/'sfx').exists(),'Sound Lab route must not be shipped'
assert 'aria-label' in source and "t('loader.error')" in source
assert source.count('mushies:managed-head:start')==1
assert '<title>Mushies</title>' in source and 'MushiesDevice' in source
assert source.count('id="portrait-guard"') == 1
assert 'mushiesDeviceChanged' in source and '100dvh' in source
for helper in ['runtime.js','runtime.css']:
 expected='\n'.join(line.rstrip() for line in (ROOT/'ui/mobile'/helper).read_text().splitlines() if line.strip())
 assert expected in source,'Export must contain the current portrait viewport helper'
manifest=json.loads((WEB/'mushies.webmanifest').read_text())
assert manifest['name']=='Mushies' and manifest['orientation']=='portrait' and manifest['display']=='fullscreen'
for icon in manifest['icons']:
 data=(WEB/icon['src']).read_bytes()
 assert data[:8] == b'\x89PNG\r\n\x1a\n'
 assert struct.unpack('>II',data[16:24]) == tuple(map(int,icon['sizes'].split('x')))
before=hashlib.sha256(source.encode()).hexdigest()
subprocess.run([sys.executable,str(ROOT/'tools/prepare_web.py')],cwd=ROOT,check=True,capture_output=True)
assert hashlib.sha256((WEB/'index.html').read_bytes()).hexdigest()==before,'Shell preparation must be idempotent'
pack=(WEB/'index.pck').read_bytes()
for required in ['scripts/multiplayer/local_match.gd','scripts/multiplayer/multiplayer_screen.gd','assets/template/bombs/puff_bomb.webp','assets/template/bombs/manifest.json','assets/template/audio_v2/runtime/bomb_pop.ogg','assets/template/plushies/runtime/chick.webp','assets/template/plushies/runtime/dragon.webp','assets/template/plushies/runtime/manifest.json','localization/en.json','localization/zh_CN.json','assets/template/ui/title.webp','assets/template/ui/pause.webp','assets/template/ui/boot.png','assets/template/fonts/NotoSansSC-VF.subset.woff2','assets/template/fonts/Nunito-VF.subset.woff2','assets/template/audio_v2/runtime/cotton_candy_circuit.ogg']:
 assert required.encode() in pack,required
for excluded in ['config/multiplayer.json','scripts/multiplayer/client.gd','scripts/multiplayer/server.gd','scripts/ranked/','services/','scripts/score/global_service.gd','legacy/','assets/template/source/','tests/','tools/','assets/template/audio_v2/source/','assets/template/plushies/source/','.venv/','assets/template/fonts/Body.ttf']:
 assert excluded.encode() not in pack,excluded
for asset in json.loads((ROOT/'assets/template/audio_v2/manifest.json').read_text())['assets']:
 assert asset['runtime'].encode() in pack,asset['runtime']
assert 1_000_000<len(pack)<7_500_000,'Keep the exported content near the shared 5 MB target plus subset CJK fonts'
assert (WEB/'index.wasm').stat().st_size>1_000_000
for name,size in json.loads(re.search(r'const GODOT_CONFIG = (.*?);',source).group(1))['fileSizes'].items():
 assert (WEB/name).stat().st_size==size,'Shell metadata must match fresh artifacts'
# Verify every generated inline JavaScript block parses without using a browser.
for index,script in enumerate(re.findall(r'<script(?:\s[^>]*)?>(.*?)</script>',source,re.S)):
 target=ROOT/'build'/f'web-script-{index}.js'; target.write_text(script)
 subprocess.run(['node','--check',str(target)],check=True,capture_output=True)
print(f'PASS: fresh localized responsive shell, exact artifact sizes, clean pack exclusions; pack {len(pack):,} bytes.')
