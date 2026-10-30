"""Release pages must not regain third-party integrations through old environment settings."""
import os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from prepare_web import render_shell
os.environ['MANUS_ANALYTICS_ENDPOINT']='https://manus-analytics.com'
os.environ['MANUS_ANALYTICS_WEBSITE_ID']='legacy-id'
for source in (ROOT/'ui/web/godot.html',ROOT/'ui/web/shell.html'):
    for installable in (True,False):
        result=render_shell(source.read_text(),installable=installable)
        assert 'manus' not in result.lower(), 'No integration tags, script URLs or service metadata may remain'
        assert 'https://www.lucasflatwhite.com/arcade/' in result
for directory in ('scripts','autoload','tools'):
    for path in (ROOT/directory).rglob('*'):
        if path.suffix in ('.gd','.cjs','.py'):
            assert 'manus' not in path.read_text().lower(), str(path.relative_to(ROOT))
assert not (ROOT/'scripts/manus').exists()
print('PASS: release shell ignores legacy analytics environment and all executable code is standalone')
