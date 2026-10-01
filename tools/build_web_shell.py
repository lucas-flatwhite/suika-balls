#!/usr/bin/env python3
"""Generate the Godot custom shell used by Addon Preview and release exports."""
import argparse
from pathlib import Path
from prepare_web import render_shell

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
source = ROOT / 'ui/web/godot.html'
target = ROOT / 'ui/web/shell.html'
rendered = render_shell(source.read_text(), installable=False)
if args.check:
    if not target.is_file() or target.read_text() != rendered:
        raise SystemExit('Mushies Web shell is stale: run python3 tools/build_web_shell.py')
else:
    target.write_text(rendered)
print('Mushies managed Web shell verified' if args.check else 'Mushies managed Web shell generated')
