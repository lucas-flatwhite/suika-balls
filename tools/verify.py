#!/usr/bin/env python3
"""One command for the native, deterministic and export acceptance gates."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get('GODOT_BIN') or shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'
BUILD = ROOT / 'build'
BUILD.mkdir(exist_ok=True)
(BUILD / 'owner').mkdir(exist_ok=True)


def run(name: str, command: list[str], extra_env: dict[str, str] | None = None, *, initial_import: bool = False) -> None:
    # Cached converted scenes can embed an older script dependency graph even
    # after the .gd sources change. Preserve imports, rebuild derived export data.
    if name in ('export', 'export-owner'):
        shutil.rmtree(ROOT / '.godot/exported', ignore_errors=True)
    result = subprocess.run(
        command, cwd=ROOT, capture_output=True, text=True, timeout=180, env={**os.environ, **(extra_env or {})}
    )
    output = result.stdout + result.stderr
    (BUILD / f'{name}.log').write_text(output)
    errors = 'SCRIPT ERROR' in output or '\nERROR:' in output
    if result.returncode or (errors and not initial_import):
        print(output[-16000:])
        raise SystemExit(f'FAILED: {name}')
    print('PASS', name, flush=True)


run('asset-retention', [sys.executable, 'tools/check_asset_retention.py'])
run('asset-retention-test', [sys.executable, 'tests/test_asset_retention.py'])
# A clean Godot editor initializes its project theme before importing font files.
# Bootstrap missing import data once, then require a clean diagnostic-free pass.
if not (ROOT / '.godot').exists():
    run('initial-import', [GODOT, '--headless', '--path', '.', '--editor', '--quit'], initial_import=True)
run('import', [GODOT, '--headless', '--path', '.', '--editor', '--quit'])
for name in (
    'gameplay',
    'resize_termination',
    'grounding',
    'template',
    'tweak_controls',
    'how_to_play',
    'title_language',
    'pc_results_fit',
    'font_layout',
    'hud_lifecycle',
    'responsive_hud',
    'cabinet_layout',
    'soundscape',
    'scenarios',
    'bomb',
    'mobile',
    'mobile_layout',
    'duel_board',
    'local_match',
    'local_splitscreen',
    'local_template',
    'username',
    'audio_settings',
    'settings_dialog',
):
    command = [GODOT, '--headless', '--audio-driver', 'Dummy', '--path', '.', '--script', f'tests/test_{name}.gd']
    if name in (
        'grounding',
        'scenarios',
        'cabinet_layout',
        'bomb',
        'mobile',
        'duel_board',
        'local_match',
        'local_splitscreen',
        'local_template',
    ):
        command += ['--fixed-fps', '60']
    run(name + '-test', command)
run('audio-assets-test', [sys.executable, 'tests/test_audio_assets.py'])
run('mobile-shell-test', ['node', 'tests/test_mobile_shell.js'])
run('loader-shell-test', ['node', 'tests/test_loader_shell.js'])
run('prepare-loader-test', [sys.executable, 'tests/test_prepare_web_loader.py'])
run('managed-shell-check', [sys.executable, 'tools/build_web_shell.py', '--check'])
run('export', [GODOT, '--headless', '--path', '.', '--export-release', 'Web', 'web/index.html'])
run('managed-loader-handoff-test', ['node', 'tests/test_loader_handoff.js', 'web/index.html'])
run('web-shell', [sys.executable, 'tools/prepare_web.py'])
run('installable-loader-handoff-test', ['node', 'tests/test_loader_handoff.js', 'web/index.html'])
run('web-build-test', [sys.executable, 'tests/test_web_build.py'])
run('pack-release', [sys.executable, 'tools/check_pack.py', 'web/index.pck'])
run('export-owner', [GODOT, '--headless', '--path', '.', '--export-debug', 'Web Owner', 'build/owner/index.html'])
run('owner-shell', [sys.executable, 'tools/prepare_web.py', '--directory', 'build/owner'])
run('pack-owner', [sys.executable, 'tools/check_pack.py', 'build/owner/index.pck'])
print(
    'Native/export gates passed. Native visual captures, CDN publication, and user browser acceptance are separately recorded.'
)
