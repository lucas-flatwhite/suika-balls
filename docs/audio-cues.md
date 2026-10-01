# Mushies audio cue sheet

The original single BGM and eighteen generated effects from baseline `55edf1d` are preserved byte-for-byte. Mushies adds a nineteenth effect, `bomb_pop`, authored procedurally as a soft fabric burst with a short low thump. `tools/prepare_bomb_audio.py` reproduces it from a fixed noise seed. Its runtime is 1.05 seconds, mono 44.1 kHz Vorbis, with measured peak −6.06 dBFS and RMS −26.91 dBFS. The cue gain is −6 dB with an 80 ms cooldown. Source/mastering provenance and decoded measurements remain in `assets/template/audio_v2/manifest.json`. Source MP3s are excluded from the game pack; production playback uses Ogg Vorbis.

| Cue | Reachable event | Bus |
| --- | --- | --- |
| cotton_candy_circuit | One continuous loop across title, play, pause, settings and results | Music |
| carriage_loop | Claw movement, with speed-dependent gain/pitch and fade-out | SFX |
| claw_open | Accepted release request | SFX |
| release_whoosh | Physical toy release | SFX |
| claw_close | Reload completes | SFX |
| impact_soft_a / impact_soft_b | Alternating light fabric collisions | SFX |
| impact_heavy | Large or strong collision | SFX |
| wall_tap | Side-wall contact | SFX |
| merge_small / merge_large | Size-dependent evolution | SFX |
| chain_bonus | Consecutive merges within the chain window | SFX |
| discovery | First appearance of a tier this run | SFX |
| dragon_arrival | Final-tier collectible accent; goal progression has no victory cue | SFX |
| danger | Sustained pile warning, debounced | SFX |
| game_over | Defeat result | SFX |
| ui_click | Confirmation, cancel, selection, toggle, slider, invalid activation and hover/focus aliases | UI |
| ui_open | Menus, settings, help, dropdown and panel opening | UI |
| restart | Starting or restarting a challenge | SFX |
| bomb_pop | Puff Bomb's five-second proximity detonation, including an empty pop | SFX |

`GameAudio.play_ui(semantic)` maps the interface aliases to the two original UI recordings with bounded pitch/gain differences. Hover/focus is quieter than confirmation; invalid activation and cancel use lower pitch. Every enabled button requests centralized feedback. Dropdowns, toggles and volume sliders also request semantic cues. Shared per-recording cooldowns prevent rapid hover/slider chatter.

Master, Music, SFX and UI player levels default to 85%, 80%, 85% and 80%. Owner gain trims are independent cosmetic offsets. A Master limiter retains headroom. Music gain fades between active/ducked/result moods without restarting the track. The carriage and low-priority effects stop on pause. Retry clears one-shots and chain/priority timers while retaining the single music timeline.

One player exists per SFX recording (at most three voices per player), plus one BGM player. Browser gestures call the same audio-unlock owner from UI and gameplay input. No UI or actor allocates a competing audio player or owns recording paths.

Verification includes actual Ogg decoding, peak/RMS/duration/channel checks, all nineteen semantic gameplay cues, mute, pause, gain routing and continuous music identity. Audible theme/mix and real-browser unlock acceptance remain user acceptance items; numerical measurements are not represented as listening evidence.
