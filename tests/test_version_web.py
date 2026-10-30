"""Immutable URLs must change with content while the game entry stays stable."""
import tempfile,sys,json,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from version_web import version_export
with tempfile.TemporaryDirectory() as temporary:
    root=Path(temporary)
    entry='<html><head><title>Game</title><link rel="manifest" href="mushies.webmanifest"></head><body><script src="index.js"></script></body></html>\n'
    (root/'index.html').write_text(entry)
    for name in ('index.js','index.wasm','index.pck','index.audio.worklet.js'):(root/name).write_bytes(name.encode())
    (root/'mushies.webmanifest').write_text(json.dumps({'start_url':'./'}))
    (root/'index.png.import').write_text('editor metadata')
    one=version_export(root)
    assert (root/'.gdignore').exists()
    assert not (root/'releases'/one/'index.png.import').exists()
    assert re.fullmatch(r'[0-9a-f]{20}',one)
    assert '<head>\n<!-- beachball:version:start --><base href="./releases/'+one+'/' in (root/'index.html').read_text()
    assert (root/'index.html').read_text().index('<base')<(root/'index.html').read_text().index('rel="manifest"')
    assert (root/'releases'/one/'index.wasm').read_bytes()==b'index.wasm'
    assert json.loads((root/'releases'/one/'mushies.webmanifest').read_text())['start_url']=='../../'
    (root/'index.png.import').write_text('changed editor metadata')
    assert version_export(root)==one,'Repeated postprocessing must not create new versions'
    (root/'index.pck').write_bytes(b'new game content')
    two=version_export(root)
    assert two!=one,'A changed pack gets a new URL'
    assert (root/'releases'/one/'index.pck').read_bytes()==b'index.pck','An old version must never be overwritten'
print('PASS: versioned engine assets, early base URL, stable entry, manifest scope, idempotence and cache invalidation')
