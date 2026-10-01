#!/usr/bin/env python3
"""Maintain managed preview archival copies while respecting explicit asset retirements."""
from pathlib import Path
import argparse,json,hashlib,shutil

def main(root):
    map_path=root/'preview-archive-map.json'
    if not map_path.exists() or not (root/'assets.lock.json').exists():
        raise SystemExit('This maintenance command requires the existing managed preview and archive map.')
    policy=json.loads((root/'tools/asset-retirement.json').read_text())
    retired_source=set(policy['retired_repository_media'])
    retired_assets=set(policy['retired_managed_assets'])
    previous=json.loads(map_path.read_text())
    records={r['original']:r for r in previous.get('files',[]) if r['original'] not in retired_source and r['managed_asset'] not in retired_assets}
    extensions={'.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg','.ico','.ogg','.wav','.mp3','.m4a','.mp4','.webm','.ttf','.otf','.woff','.woff2'}
    copied=0
    for directory in ('concepts','legacy','validation-assets','docs'):
        for original in sorted((root/directory).rglob('*')):
            if not original.is_file() or original.suffix.lower() not in extensions:continue
            relative=original.relative_to(root).as_posix()
            target_rel='assets/template/upstream_archive/'+relative
            if relative in retired_source or target_rel in retired_assets:continue
            target=root/target_rel;target.parent.mkdir(parents=True,exist_ok=True)
            digest=hashlib.sha256(original.read_bytes()).hexdigest()
            if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest()!=digest:
                shutil.copy2(original,target);copied+=1
            records[relative]={'original':relative,'managed_asset':target_rel,'sha256':digest}
    for record in records.values():
        target=root/record['managed_asset']
        assert target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest()==record['sha256']
    map_path.write_text(json.dumps({'purpose':'Only non-retired supplied archival media is eligible for managed copies. Approved retirements are recorded in tools/asset-retirement.json. No remote deletion is performed.','files':[records[key] for key in sorted(records)]},indent=2)+'\n')
    print(f'Archive maintenance: {len(records)} retained entries, {copied} copied; approved retired paths skipped.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    main(parser.parse_args().root.resolve())
