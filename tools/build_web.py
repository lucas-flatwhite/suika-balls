#!/usr/bin/env python3
"""Build the game with a locally installed Godot, without an external runtime."""
import os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT_BIN') or shutil.which('godot')
if not GODOT:raise SystemExit('Install Godot 4.7.2 with Web export templates, or set GODOT_BIN')
OUTPUT=ROOT/'dist'
OUTPUT.mkdir(exist_ok=True)
(OUTPUT/'.gdignore').touch()
def run(command):
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    output=result.stdout+result.stderr
    print(output,end='')
    if result.returncode or 'SCRIPT ERROR' in output or '\nERROR:' in output:
        raise SystemExit('Web build command failed: '+str(command[0]))
run([sys.executable,'tools/build_web_shell.py'])
run([GODOT,'--headless','--editor','--path',str(ROOT),'--quit'])
run([GODOT,'--headless','--path',str(ROOT),'--export-release','Web',str(OUTPUT/'index.html')])
run([sys.executable,'tools/prepare_web.py','--directory','dist'])
