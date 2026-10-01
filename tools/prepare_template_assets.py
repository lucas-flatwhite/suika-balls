"""Deterministic runtime derivatives from retained generated art and licensed fonts."""
from pathlib import Path
import json, shutil
from PIL import Image
from install_cjk_font import install_font
ROOT=Path(__file__).resolve().parents[1]
for key in ('title','pause','foreground'):
 source=ROOT/'assets/template/source'/f'{key}.png'
 image=Image.open(source)
 if key=='title': image.resize((1280,854),Image.Resampling.LANCZOS).save(ROOT/'assets/template/ui/title.webp',quality=86)
 elif key=='pause': image.resize((640,640),Image.Resampling.LANCZOS).save(ROOT/'assets/template/ui/pause.webp',quality=90,method=6)
 else:
  image.crop((0,705,image.width,image.height)).resize((336,70),Image.Resampling.LANCZOS).save(ROOT/'assets/template/foregrounds/cabinet_trim.webp',quality=90,method=6)
 print(key,image.mode,image.size)
font_target=install_font(ROOT)
Image.open(ROOT/'assets/template/source/normalized/chick.png').resize((186,192),Image.Resampling.LANCZOS).save(ROOT/'assets/template/ui/boot.png',optimize=True)
for size in (192,512):
 chick=Image.open(ROOT/'assets/template/source/normalized/chick.png').convert('RGBA')
 chick.thumbnail((int(size*0.82),int(size*0.82)),Image.Resampling.LANCZOS)
 icon=Image.new('RGBA',(size,size),'#f5e8de')
 icon.alpha_composite(chick,((size-chick.width)//2,(size-chick.height)//2))
 icon.convert('RGB').save(ROOT/f'assets/template/ui/app-icon-{size}.png',optimize=True)
print('Common SC font:',font_target.stat().st_size,'bytes')
