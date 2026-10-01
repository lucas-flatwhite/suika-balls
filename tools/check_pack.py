#!/usr/bin/env python3
"""Run an exported pack in an empty directory, without checkout resource fallback."""
import argparse, os, subprocess, tempfile, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('pack',type=Path);args=parser.parse_args()
godot=os.environ.get('GODOT_BIN') or shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'
with tempfile.TemporaryDirectory(prefix='plushie-pack-') as directory:
 for script in ('pack_probe.gd', 'test_resize_termination.gd','test_grounding.gd','test_hud_lifecycle.gd','test_cabinet_layout.gd','test_bomb.gd','test_mobile.gd','test_local_template.gd','test_local_splitscreen.gd'):
  command=[godot,'--headless','--path',directory,'--main-pack',str(args.pack.resolve()),'--script',str(ROOT/'tests'/script)]
  if script in ('test_grounding.gd','test_cabinet_layout.gd','test_bomb.gd','test_mobile.gd','test_local_template.gd','test_local_splitscreen.gd'): command+=['--fixed-fps','60']
  result=subprocess.run(command,capture_output=True,text=True,timeout=45)
  print(result.stdout,end=''); print(result.stderr,end='')
  output=result.stdout+result.stderr
  if result.returncode or 'ERROR:' in output: raise SystemExit(1)
  assert 'PASS:' in result.stdout
