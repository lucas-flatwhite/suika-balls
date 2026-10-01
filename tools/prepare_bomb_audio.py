"""Author one original soft fabric-pop cue through the existing offline sound bank."""
from pathlib import Path
import json
import subprocess
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
rate = 44100
t = np.arange(int(rate * 1.05)) / rate
rng = np.random.default_rng(0xB0B)
noise = rng.standard_normal(len(t))
soft = np.convolve(noise, np.ones(19) / 19, mode='same')
air = noise - np.convolve(noise, np.ones(7) / 7, mode='same')
envelope = (1 - np.exp(-t * 350)) * np.exp(-t * 8)
thump = np.sin(2 * np.pi * (95 * t + 6 * (1 - np.exp(-t * 14)))) * np.exp(-t * 16)
signal = (0.7 * soft + 0.045 * air) * envelope + 0.35 * thump * (1 - np.exp(-t * 600))
signal *= np.minimum(1, (1.05 - t) / 0.04)
signal *= 0.5 / np.max(np.abs(signal))
source = ROOT / 'assets/template/audio_v2/source/bomb_pop.mp3'
runtime = ROOT / 'assets/template/audio_v2/runtime/bomb_pop.ogg'
pcm = signal.astype('<f4').tobytes()
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(rate), '-ac', '1', '-i', 'pipe:0', '-c:a', 'libmp3lame', '-q:a', '2', str(source)], input=pcm, check=True)
sf.write(runtime, signal, rate, format='OGG', subtype='VORBIS')
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(runtime), '-f', 'f32le', '-ar', str(rate), '-ac', '1', 'pipe:1'], capture_output=True, check=True).stdout
decoded = np.frombuffer(raw, dtype='<f4')
record = {'key': 'bomb_pop', 'kind': 'SFX', 'generator': 'Original procedural fabric burst and low thump',
          'authoring_script': 'tools/prepare_bomb_audio.py', 'source': source.relative_to(ROOT).as_posix(),
          'runtime': runtime.relative_to(ROOT).as_posix(), 'source_seconds': 1.05,
          'duration_seconds': round(len(decoded)/rate, 4), 'channels': 1, 'sample_rate': rate, 'loop': False,
          'peak_dbfs': round(float(20*np.log10(np.max(np.abs(decoded)))), 2),
          'rms_dbfs': round(float(20*np.log10(np.sqrt(np.mean(decoded.astype(float)**2)))), 2), 'bytes': runtime.stat().st_size}
path = ROOT / 'assets/template/audio_v2/manifest.json'
manifest = json.loads(path.read_text())
manifest['assets'] = [entry for entry in manifest['assets'] if entry['key'] != record['key']] + [record]
path.write_text(json.dumps(manifest, indent=2)+'\n')
print(json.dumps(record, indent=2))
