"""Remove production key color and preserve generated silhouettes at cursor scale."""
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
for key in ('cursor','aim_cursor'):
 im=Image.open(ROOT/'assets/template/source'/f'{key}.png').convert('RGBA')
 a=np.array(im)
 green=(a[:,:,1].astype(float)-np.maximum(a[:,:,0],a[:,:,2]))
 keyed=green>45
 a[:,:,3][keyed]=0
 im=Image.fromarray(a)
 bounds=im.getchannel('A').point(lambda value: 255 if value>128 else 0).getbbox()
 bounds=(max(0,bounds[0]-4),max(0,bounds[1]-4),min(im.width,bounds[2]+4),min(im.height,bounds[3]+4))
 im=im.crop(bounds)
 canvas=Image.new('RGBA',(32,32))
 im.thumbnail((28,28),Image.Resampling.LANCZOS)
 canvas.alpha_composite(im,((32-im.width)//2,(32-im.height)//2))
 canvas.save(ROOT/'assets/template/ui'/f'{key}.png',optimize=True)
 print(key,'source crop',bounds,'runtime alpha',canvas.getextrema()[3])
