"""Crop and resize the retained generated sprite; preserve its real alpha."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / 'assets/template/source/puff_bomb.png').convert('RGBA')
alpha = source.getchannel('A')
assert alpha.getextrema() == (0, 255), 'The generated sprite needs genuine transparency'
bounds = alpha.point(lambda value: 255 if value > 100 else 0).getbbox()
padding = 12
crop = (max(0, bounds[0]-padding), max(0, bounds[1]-padding),
        min(source.width, bounds[2]+padding), min(source.height, bounds[3]+padding))
sprite = source.crop(crop)
sprite.thumbnail((512, 512), Image.Resampling.LANCZOS)
sprite.putalpha(sprite.getchannel('A').point(lambda value: 0 if value < 20 else value))
sprite.save(ROOT / 'assets/template/bombs/puff_bomb.webp', quality=90, method=6)
print(json.dumps({'source': source.size, 'crop': crop, 'runtime': sprite.size,
                  'alpha': sprite.getchannel('A').getextrema()}))
