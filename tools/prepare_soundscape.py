#!/usr/bin/env python3
"""Master generated plushie audio; measure every exported stream."""
from pathlib import Path
import json
import subprocess
import tempfile
import numpy as np
import soundfile as sf

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/template/audio_v2'
SFX=['carriage_loop','claw_open','claw_close','release_whoosh','impact_soft_a','impact_soft_b','impact_heavy','wall_tap','merge_small','merge_large','chain_bonus','discovery','dragon_arrival','danger','game_over','ui_click','ui_open','restart','bomb_pop']
RATE=44100

def run(args,**kwargs):
    return subprocess.run(args,check=True,**kwargs)

def decode(path,channels):
    result=run(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ar',str(RATE),'-ac',str(channels),'pipe:1'],stdout=subprocess.PIPE)
    return np.frombuffer(result.stdout,dtype='<f4').reshape(-1,channels).copy()

def encode(samples,path,channels,filter_text=None):
    if filter_text:
        args=['ffmpeg','-v','error','-f','f32le','-ar',str(RATE),'-ac',str(channels),'-i','pipe:0','-af',filter_text,'-ar',str(RATE),'-ac',str(channels),'-f','f32le','pipe:1']
        result=run(args,input=samples.astype('<f4').tobytes(),stdout=subprocess.PIPE)
        samples=np.frombuffer(result.stdout,dtype='<f4').reshape(-1,channels)
    # libsndfile supplies Vorbis even when the system FFmpeg omits libvorbis.
    sf.write(path,samples,RATE,format='OGG',subtype='VORBIS')

def loop_crossfade(samples,seconds):
    n=min(int(seconds*RATE),len(samples)//4)
    output=samples[n:].copy()
    mix=np.linspace(0,1,n,endpoint=False,dtype=np.float32)[:,None]
    output[-n:]=output[-n:]*(1-mix)+samples[:n]*mix
    return output

def main():
    records=[]
    for key in SFX+['cotton_candy_circuit']:
        music=key=='cotton_candy_circuit'
        channels=2 if music else 1
        source=BASE/'source'/f'{key}.mp3'
        dest=BASE/'runtime'/f'{key}.ogg'
        samples=decode(source,channels)
        source_duration=len(samples)/RATE
        loop=music or key=='carriage_loop'
        if loop:
            samples=loop_crossfade(samples,2.0 if music else 0.10)
        else:
            # Tiny edge ramps prevent encode/decode boundary clicks without trimming gestures.
            fade=min(int(RATE*0.005),len(samples)//8)
            samples[:fade]*=np.linspace(0,1,fade)[:,None]
            samples[-fade:]*=np.linspace(1,0,fade)[:,None]
        peak=float(np.max(np.abs(samples)))
        if peak<0.00001: raise ValueError(f'{key}: source is effectively silent')
        if not music:
            # Peak-normalize foley to -6 dBFS, but never add over 12 dB of gain.
            gain=min(0.5/peak,4.0)
            samples*=gain
        encode(samples,dest,channels,'loudnorm=I=-20:TP=-3:LRA=7' if music else None)
        decoded=decode(dest,channels)
        peak=float(np.max(np.abs(decoded)))
        rms=float(np.sqrt(np.mean(np.square(decoded,dtype=np.float64))))
        assert 0.000001<rms and peak<0.96,(key,rms,peak)
        if music:
            metrics=run(['ffmpeg','-hide_banner','-i',str(dest),'-af','loudnorm=I=-20:TP=-3:LRA=7:print_format=json','-f','null','-'],stderr=subprocess.PIPE)
            stderr=metrics.stderr.decode()
            stats=json.loads(stderr[stderr.rfind('{'):stderr.rfind('}')+1])
        else: stats=None
        record={'key':key,'kind':'BGM' if music else 'SFX','generator':'Original procedural fabric burst and low thump' if key=='bomb_pop' else ('built-in Lyria music generation' if music else 'built-in ElevenLabs sound-effect generation'),'source':str(source.relative_to(ROOT)),'runtime':str(dest.relative_to(ROOT)),'source_seconds':round(source_duration,4),'duration_seconds':round(len(decoded)/RATE,4),'channels':channels,'sample_rate':RATE,'loop':loop,'peak_dbfs':round(20*np.log10(max(peak,1e-12)),2),'rms_dbfs':round(20*np.log10(max(rms,1e-12)),2),'bytes':dest.stat().st_size}
        if stats: record['loudness_measurement']=stats
        records.append(record)
        print(f'{key}: {record["duration_seconds"]}s, peak {record["peak_dbfs"]} dBFS, {record["bytes"]} bytes',flush=True)
    (BASE/'manifest.json').write_text(json.dumps({'version':2,'assets':records},indent=2)+'\n')
    print('Mastered 19 SFX + 1 BGM.')

if __name__=='__main__': main()
