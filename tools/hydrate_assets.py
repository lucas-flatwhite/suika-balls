#!/usr/bin/env python3
"""Restore lock-backed assets atomically with path, host, size and SHA-256 validation."""
import hashlib,json,os,tempfile,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
lock_path=ROOT/'assets.lock.json'
if not lock_path.exists(): raise SystemExit('No published assets.lock.json yet. Finish approved CDN publication before distributing a clean scaffold.')
lock=json.loads(lock_path.read_text());assert lock['version']==2
for key,record in lock['assets'].items():
 target=(ROOT/key).resolve()
 if not key.startswith('assets/template/') or not target.is_relative_to(ROOT/'assets/template') or key.endswith('.import'): raise ValueError('Invalid asset path: '+key)
 def matches(data): return len(data)==record['size'] and 'sha256:'+hashlib.sha256(data).hexdigest()==record['sha256']
 if target.is_file() and matches(target.read_bytes()): continue
 url=record['path']
 if not url.startswith(('https://files.manuscdn.com/','https://d1oupeiobkpcny.cloudfront.net/')) or '?' in url: raise ValueError('Unapproved public asset URL')
 with urllib.request.urlopen(url,timeout=90) as response: data=response.read()
 if not matches(data): raise ValueError('Asset bytes failed validation: '+key)
 target.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.NamedTemporaryFile(dir=target.parent,delete=False) as temporary:
  temporary.write(data); temporary_name=temporary.name
 os.replace(temporary_name,target)
 print('Restored',key)
