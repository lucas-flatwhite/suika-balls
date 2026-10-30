#!/usr/bin/env python3
"""Publish a stable HTML entry with content-addressed Godot runtime assets."""
from __future__ import annotations
import hashlib,json,re
from pathlib import Path

START='<!-- beachball:version:start -->'
END='<!-- beachball:version:end -->'

def version_export(directory: Path) -> str | None:
    directory=directory.resolve()
    (directory/'.gdignore').touch()
    required=[directory/f'index.{extension}' for extension in ('js','wasm','pck')]
    if not any(path.exists() for path in required):
        return None # Shell-only fixtures have no exported engine yet.
    if not all(path.is_file() for path in required):
        raise RuntimeError('A complete Godot JS/WASM/PCK export is required')
    entry=directory/'index.html'
    source=re.sub(r'\n?<!-- beachball:version:start -->.*?<!-- beachball:version:end -->','',entry.read_text(),flags=re.S)
    files=sorted(path for path in directory.rglob('*') if path.is_file()
                 and path!=entry and path.relative_to(directory).parts[0]!='releases'
                 and not any(part.startswith('.') for part in path.relative_to(directory).parts)
                 and path.suffix not in ('.import','.uid'))
    digest=hashlib.sha256(source.encode())
    for path in files:
        relative=path.relative_to(directory).as_posix().encode()
        content=path.read_bytes()
        digest.update(len(relative).to_bytes(8,'big'));digest.update(relative)
        digest.update(len(content).to_bytes(8,'big'));digest.update(content)
    version=digest.hexdigest()[:20]
    target=directory/'releases'/version
    def publish(relative: Path, content: bytes) -> None:
        path=target/relative
        path.parent.mkdir(parents=True,exist_ok=True)
        if path.exists() and path.read_bytes()!=content:
            raise RuntimeError('Refusing to overwrite an immutable release asset: '+str(relative))
        path.write_bytes(content)
    for path in files:
        content=path.read_bytes()
        if path.suffix=='.webmanifest':
            manifest=json.loads(content)
            manifest.update(start_url='../../',scope='../../')
            content=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
        publish(path.relative_to(directory),content)
    publish(Path('index.html'),source.encode())
    base=f'{START}<base href="./releases/{version}/">{END}'
    result,count=re.subn(r'<head(?:\s[^>]*)?>',lambda match:match[0]+'\n'+base,source,count=1,flags=re.I)
    if count!=1:raise RuntimeError('The game HTML has no head for its release base URL')
    entry.write_text(result)
    return version
