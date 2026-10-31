#!/usr/bin/env python3
"""Cut Anybody down to the word on the Arcade chip and embed it in ui/web/arcade.css.

The source is the variable latin Anybody woff2 that flatwhite-arcade ships, for example
node_modules/@fontsource-variable/anybody/files/anybody-latin-wdth-normal.woff2 there.
Needs fonttools and brotli.
"""
import argparse
import base64
import io
import re
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[1]
CSS = ROOT / 'ui/web/arcade.css'
TEXT = 'Arcade'

parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument('source', type=Path)
args = parser.parse_args()

font = instancer.instantiateVariableFont(TTFont(args.source), {'wght': 600, 'wdth': 105})
options = subset.Options()
options.flavor = 'woff2'
options.layout_features = ['kern']
options.name_IDs = ['*']
subsetter = subset.Subsetter(options)
subsetter.populate(text=TEXT)
subsetter.subset(font)
font.flavor = 'woff2'
buffer = io.BytesIO()
font.save(buffer)
data = base64.b64encode(buffer.getvalue()).decode()
css, count = re.subn(r'url\(data:font/woff2;base64,[^)]*\)', f'url(data:font/woff2;base64,{data})', CSS.read_text(), count=1)
if count != 1:
    raise SystemExit('ui/web/arcade.css has no embedded chip font to replace')
CSS.write_text(css)
print(f'Arcade chip font embedded: {len(buffer.getvalue())} bytes')
