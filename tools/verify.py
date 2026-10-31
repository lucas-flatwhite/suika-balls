#!/usr/bin/env python3
"""Validate the current Beach Ball Merge game and its standalone Web shell."""
import os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT_BIN') or shutil.which('godot')
if not GODOT:raise SystemExit('Install Godot 4.7.2 or set GODOT_BIN')
LOGS=ROOT/'build/validation';LOGS.mkdir(parents=True,exist_ok=True)
def run(name,command):
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
    output=result.stdout+result.stderr
    (LOGS/(name+'.log')).write_text(output)
    if result.returncode or 'SCRIPT ERROR' in output or '\nERROR:' in output:
        print(output[-8000:]);raise SystemExit('FAILED: '+name)
    print('PASS: '+name,flush=True)
run('import',[GODOT,'--headless','--editor','--path',str(ROOT),'--quit'])
for name in ('ball_rules','ball_i18n','restart_score','frame_work','match_frame_work','arcade_chip'):
    run(name,[GODOT,'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(ROOT),'--script',f'tests/test_{name}.gd'])
for name in ('arcade_navigation','standalone_web','version_web','prepare_web_loader','standalone_assets'):
    run(name,[sys.executable,f'tests/test_{name}.py'])
for name in ('mobile_shell','loader_shell','release_cache'):
    run(name,['node',f'tests/test_{name}.js'])
run('generated-shell',[sys.executable,'tools/build_web_shell.py','--check'])
print('Native game and standalone shell checks passed. Run npm run build for Web export; browser acceptance is separate.')
