#!/usr/bin/env python3
"""Validate the complete plushie sound bank with actual decoded audio measurements."""
import json
import subprocess
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    records=json.loads((ROOT/'assets/template/audio_v2/manifest.json').read_text())['assets']
    assert len(records)==20
    assert sum(a['kind']=='BGM' for a in records)==1
    assert sum(a['kind']=='SFX' for a in records)==19
    assert len({a['key'] for a in records})==20
    for record in records:
        source=ROOT/record['source']
        runtime=ROOT/record['runtime']
        assert source.is_file() and source.stat().st_size>1000
        assert runtime.is_file() and runtime.read_bytes().startswith(b'OggS')
        result=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_name,sample_rate,channels','-of','json',str(runtime)],check=True,capture_output=True,text=True)
        media=json.loads(result.stdout)
        stream=media['streams'][0]
        assert stream['codec_name']=='vorbis'
        assert int(stream['sample_rate'])==44100
        duration=float(media['format']['duration'])
        # Container timing includes codec/resampler padding; the decoded PCM is authoritative.
        pcm=subprocess.run(['ffmpeg','-v','error','-i',str(runtime),'-f','f32le','-ar','44100','-ac',str(stream['channels']),'pipe:1'],check=True,capture_output=True).stdout
        decoded_duration=len(pcm)/(4*int(stream['channels'])*44100)
        assert abs(decoded_duration-record['duration_seconds'])<0.001
        assert abs(duration-decoded_duration)<0.15,(record['key'],duration,decoded_duration)
        assert int(stream['channels'])==(2 if record['kind']=='BGM' else 1)
        result=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(runtime),'-af','volumedetect','-f','null','-'],check=True,capture_output=True,text=True)
        peak=float(re.search(r'max_volume:\s+(-?[0-9.]+) dB',result.stderr).group(1))
        mean=float(re.search(r'mean_volume:\s+(-?[0-9.]+) dB',result.stderr).group(1))
        assert -45<mean<-8,(record['key'],mean)
        assert -30<peak<-1,(record['key'],peak)
        assert (75<duration<180) if record['kind']=='BGM' else (0.3<duration<3)
        assert record['loop']==(record['key'] in ('carriage_loop','cotton_candy_circuit'))
    music=next(a for a in records if a['kind']=='BGM')
    assert -22<float(music['loudness_measurement']['input_i'])<-18
    for name in ('game_audio.gd','sound_bank.gd'):
        script=(ROOT/'scripts'/name).read_text()
        assert 'http://' not in script and 'https://' not in script
        assert 'assets/template/audio/runtime/' not in script
    print('PASS: 19 SFX + 1 BGM; decoded Ogg format, duration, levels, local-only routing and source provenance.')

if __name__=='__main__': main()
