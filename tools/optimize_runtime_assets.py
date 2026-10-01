"""Lossy color/alpha-preserving derivatives; never alter collision coordinates."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
for path in (ROOT/'assets/template/source/normalized').glob('*.png'):
 Image.open(path).save(ROOT/'assets/template/plushies/runtime'/path.with_suffix('.webp').name,quality=90,method=6)
image=Image.open(ROOT/'assets/template/source/arcade.png')
image.resize((1280,800),Image.Resampling.LANCZOS).save(ROOT/'assets/template/plushies/background/arcade.webp',quality=86,method=6)
print('Runtime WebP derivatives saved with source alpha preserved.')
