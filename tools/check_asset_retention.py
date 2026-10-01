#!/usr/bin/env python3
"""Verify the approved housekeeping policy without modifying files or CDN storage."""
from pathlib import Path
import argparse,hashlib,json
ROOT=Path(__file__).resolve().parents[1]

def check(root):
    policy=json.loads((root/'tools/asset-retirement.json').read_text())
    errors=[]
    retired=set(policy['retired_repository_media']+policy['retired_managed_assets']+policy['retired_sidecars']+policy['upstream_font_replacement']['retired'])
    for rel in sorted(retired):
        if (root/rel).exists():errors.append('Retired path returned: '+rel)
    retained=policy['retained_asset_hashes']
    for rel,wanted in retained.items():
        path=root/rel
        if not path.is_file():errors.append('Missing retained asset: '+rel)
        elif 'sha256:'+hashlib.sha256(path.read_bytes()).hexdigest()!=wanted:errors.append('Retained asset changed without policy update: '+rel)
    font_directories={Path(rel).parent for rel in policy['upstream_font_replacement']['replacement']}
    for directory in sorted(font_directories):
        for path in sorted((root/directory).rglob('*')):
            if path.is_file() and path.suffix.lower() in {'.ttf','.otf','.woff','.woff2'}:
                rel=path.relative_to(root).as_posix()
                if rel not in retained:errors.append('Unapproved runtime font: '+rel)
    for path in (root/'assets/template').rglob('*.import'):
        if not Path(str(path)[:-len('.import')]).exists():errors.append('Orphan import sidecar: '+str(path.relative_to(root)))
    lock=root/'assets.lock.json'
    if lock.exists():
        manifest=json.loads(lock.read_text())
        for rel,entry in manifest['assets'].items():
            if rel in retired:errors.append('Retired lock entry: '+rel)
            path=root/rel
            if not path.is_file():errors.append('Lock entry missing local file: '+rel);continue
            if entry['size']!=path.stat().st_size or entry['sha256']!='sha256:'+hashlib.sha256(path.read_bytes()).hexdigest():errors.append('Lock bytes mismatch: '+rel)
        if set(manifest['assets'])!=set(retained):errors.append('Managed manifest differs from approved retained asset inventory')
    if errors:raise SystemExit('\n'.join(errors))
    print(f'PASS: {len(retained)} retained assets are byte-identical; runtime fonts are approved; retired media, orphan imports and stale lock entries absent.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=ROOT)
    check(parser.parse_args().root.resolve())
