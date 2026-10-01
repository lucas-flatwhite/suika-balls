#!/usr/bin/env python3
"""Inventory local assets and, when present, verify Runtime v2 lock byte identity."""
import argparse, collections, hashlib, json, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TYPES={**dict.fromkeys(['png','jpg','jpeg','webp','gif','bmp','svg','ico'],'image'),**dict.fromkeys(['ogg','wav','mp3','m4a'],'audio'),**dict.fromkeys(['mp4','webm'],'video'),**dict.fromkeys(['ttf','otf','woff','woff2'],'font')}
def inventory():
 return {p.relative_to(ROOT).as_posix():{'size':p.stat().st_size,'sha256':'sha256:'+hashlib.sha256(p.read_bytes()).hexdigest(),'assetType':TYPES[p.suffix[1:].lower()]} for p in sorted((ROOT/'assets/template').rglob('*')) if p.is_file() and p.suffix[1:].lower() in TYPES}
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--remote',action='store_true');parser.add_argument('--require-lock',action='store_true');args=parser.parse_args()
 assets=inventory();counts=collections.Counter(Path(p).suffix for p in assets)
 report={'assets':len(assets),'extensions':dict(counts),'bytes':sum(v['size'] for v in assets.values()),'excludedImportFiles':len(list((ROOT/'assets/template').rglob('*.import'))),'uploaded':0,'preserved':0,'validation':'blocked: no published lock'}
 errors=[]; lock_path=ROOT/'assets.lock.json'
 if lock_path.exists():
  lock=json.loads(lock_path.read_text())
  assert lock.get('version')==2 and all(isinstance(lock.get(k),dict) for k in ('groups','bundles','assets'))
  for key in set(assets)|set(lock['assets']):
   if key not in assets or key not in lock['assets']: errors.append('Inventory mismatch: '+key);continue
   entry=lock['assets'][key]
   if any(entry.get(field)!=assets[key][field] for field in ('size','sha256','assetType')): errors.append('Metadata mismatch: '+key)
   if entry.get('groupId') not in lock['groups']: errors.append('Unknown group: '+key)
   url=entry.get('path','')
   if not url.startswith(('https://files.manuscdn.com/','https://d1oupeiobkpcny.cloudfront.net/')) or '/game-template/' not in url or '?' in url: errors.append('Nonpermanent URL: '+key);continue
   if args.remote:
    with urllib.request.urlopen(url,timeout=60) as response: data=response.read()
    if len(data)!=assets[key]['size'] or 'sha256:'+hashlib.sha256(data).hexdigest()!=assets[key]['sha256']: errors.append('Remote mismatch: '+key)
  report['validation']='passed remote bytes' if args.remote and not errors else ('passed local metadata' if not errors else 'failed')
  report['validated']=len(assets)-len(errors)
 elif args.require_lock: errors.append('CDN publication requires approved credentials and the repository publisher.')
 (ROOT/'docs/asset-inventory.json').write_text(json.dumps({'summary':report,'errors':errors,'assets':assets},indent=2)+'\n')
 print(json.dumps(report,indent=2))
 if errors: print('\n'.join(errors)); raise SystemExit(1)
if __name__=='__main__':main()
