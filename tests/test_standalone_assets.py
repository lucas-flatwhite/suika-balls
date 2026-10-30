"""Every literal runtime resource reference must resolve without remote hydration."""
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files=[ROOT/'project.godot']
for directory in ('scripts','autoload','scenes','data','config','assets'):
    files.extend(path for path in (ROOT/directory).rglob('*') if path.suffix in ('.gd','.tscn','.tres'))
checked=0
for path in files:
    for relative in re.findall(r'res://([^"\n]+)',path.read_text()):
        if '%' in relative or '*' in relative:continue
        assert (ROOT/relative).exists(),str(path.relative_to(ROOT))+': '+relative
        checked+=1
for name in ('assets/fonts/Jua-OFL.txt','assets/template/fonts/Nunito-OFL.txt','assets/template/fonts/NotoSansSC-OFL.txt','ui/web/GODOT-LICENSE.txt'):
    assert (ROOT/name).is_file(),name
print(f'PASS: {checked} runtime resource references resolve locally; font and engine licenses retained')
