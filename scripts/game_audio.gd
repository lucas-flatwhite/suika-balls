extends Node
class_name GameAudio
## 효과음 파일 없이 코드로 합성한 소리(PCM)를 재생합니다.
## 공마다 다른 충돌음(탁구공 '똑', 골프공 '딱', 농구공 '퉁', 비치볼 '뽀옹'),
## 단계가 높을수록 높고 화려해지는 합체음, 동시 재생 수 제한, 첫 입력 뒤에만 재생.
signal cue_played(cue_name: StringName)

enum MusicMood { ACTIVE, DUCKED, GAME_OVER }
const RATE := 22050
const SFX_VOICES := 10
const MAX_IMPACT_VOICES := 3

var muted := false
var music_enabled := true
var sfx_enabled := true
var music_mood := MusicMood.ACTIVE
var unlocked := false
var _cache: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _ui_voices: Array[AudioStreamPlayer] = []
var _voice_kind: Dictionary = {}
var _next_voice := 0
var _next_ui := 0
var _clock := 0.0
var _last_play: Dictionary = {}
var _last_merge := -99.0
var chain_count := 0
var _priority_until := 0.0
var _warm_queue: Array[StringName] = []
var music_start_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(SFX_VOICES):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_voices.append(player)
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = &"UI"
		add_child(player)
		_ui_voices.append(player)
	for tier in range(10): _warm_queue.append(StringName("impact_%d" % tier))
	for tier in range(10): _warm_queue.append(StringName("merge_%d" % tier))
	_warm_queue.append_array([&"drop", &"ui_click", &"ui_open", &"ui_cancel", &"danger", &"restart", &"discovery", &"game_over", &"final", &"wall"])
	_apply_bus_mutes()

func _process(delta: float) -> void:
	_clock += delta
	# Synthesize a couple of cues per frame after the first input, never in one block.
	if unlocked and not _warm_queue.is_empty():
		for index in range(2):
			if _warm_queue.is_empty(): break
			_stream(_warm_queue.pop_front())

## 첫 터치/클릭/키 입력 때 호출됩니다(자동재생 정책).
func unlock() -> void:
	unlocked = true

func ensure_music_playing() -> void:
	pass

func set_muted(value: bool) -> void:
	muted = value
	_apply_bus_mutes()
	if muted: _stop_one_shots()

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	_apply_bus_mutes()

func set_sfx_enabled(value: bool) -> void:
	sfx_enabled = value
	_apply_bus_mutes()
	if not sfx_enabled: _stop_one_shots()

func _apply_bus_mutes() -> void:
	var bus_mutes := {&"Music":muted or not music_enabled,
		&"SFX":muted or not sfx_enabled, &"UI":muted or not sfx_enabled}
	for bus in bus_mutes:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0: AudioServer.set_bus_mute(index,bus_mutes[bus])

func set_music_mood(mood: MusicMood) -> void:
	music_mood = mood

func set_carriage_motion(_speed: float) -> void:
	pass

# ---------------------------------------------------------------- cues

func play_drop(_tier: int) -> void:
	_play(&"drop", randf_range(0.96, 1.04), -4.0)

func play_release() -> void:
	pass

func play_claw_close() -> void:
	pass

func play_bomb_pop() -> void:
	pass

func play_impact(strength: float = 0.5, tier: int = 0, wall: bool = false) -> void:
	if not _can_play() or music_mood != MusicMood.ACTIVE or _clock < _priority_until: return
	if _active_kind("impact") >= MAX_IMPACT_VOICES: return
	var cue := StringName("impact_%d" % clampi(tier, 0, 9))
	var gain := lerpf(-12.0, 0.0, clampf(strength, 0.0, 1.0))
	if wall: gain -= 2.0
	_play(cue, randf_range(0.95, 1.05), gain, "impact", 0.03)

func play_merge(tier: int, first_discovery: bool = false) -> void:
	chain_count = chain_count + 1 if _clock - _last_merge <= 1.2 else 1
	_last_merge = _clock
	if not _can_play(): return
	_play(StringName("merge_%d" % clampi(tier, 0, 9)), 1.0 + minf(float(chain_count - 1), 4.0) * 0.03, 0.0, "merge", 0.0)
	if first_discovery: _play(&"discovery", 1.0, -5.0, "merge", 0.0)

func play_danger() -> void:
	_play(&"danger", 1.0, -3.0)

func play_game_over() -> void:
	_stop_one_shots()
	_priority_until = _clock + 1.2
	_play(&"game_over", 1.0, 0.0, "fx", 0.0)

func play_victory() -> void:
	_priority_until = _clock + 0.8
	_play(&"final", 1.0, 0.0, "fx", 0.0)

func play_restart() -> void:
	clear_transients()
	set_music_mood(MusicMood.ACTIVE)
	_play(&"restart", 1.0, -4.0)

func play_ui_click() -> void:
	play_ui("click")

func play_ui_open() -> void:
	play_ui("open")

func play_ui_soft() -> void:
	play_ui("click")

func play_ui(semantic: String) -> void:
	var cue := &"ui_click"
	var pitch := 1.0
	match semantic:
		"open": cue = &"ui_open"
		"cancel": cue = &"ui_cancel"
		"toggle", "select": pitch = 1.12
		"invalid": pitch = 0.7
	_play(cue, pitch, -4.0, "ui", 0.04, true)

func clear_transients() -> void:
	_stop_one_shots()
	_last_play.clear()
	_last_merge = -99
	_priority_until = 0
	chain_count = 0

func apply_settings(values: Dictionary, tuning: Dictionary) -> void:
	for pair in [["Master","master"],["Music","music"],["SFX","sfx"],["UI","ui"]]:
		var index := AudioServer.get_bus_index(pair[0])
		var gain: float = tuning.get("audio." + pair[1] + ".gain", 0.0)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001,float(values[pair[1]]))) + gain)
	set_music_enabled(bool(values.get("music_enabled",true)))
	set_sfx_enabled(bool(values.get("sfx_enabled",true)))
	set_muted(bool(values.muted))

func _can_play() -> bool:
	return unlocked and not muted and sfx_enabled

func _active_kind(kind: String) -> int:
	var count := 0
	for player in _voices:
		if player.playing and _voice_kind.get(player.get_instance_id(), "") == kind: count += 1
	return count

func _play(cue: StringName, pitch := 1.0, gain := 0.0, kind := "fx", cooldown := 0.05, ui := false) -> bool:
	if not _can_play(): return false
	if _clock - float(_last_play.get(cue, -99.0)) < cooldown: return false
	var stream := _stream(cue)
	if stream == null: return false
	var player: AudioStreamPlayer
	if ui:
		player = _ui_voices[_next_ui % _ui_voices.size()]
		_next_ui += 1
	else:
		# Prefer an idle voice; otherwise steal the oldest round-robin slot.
		player = null
		for offset in range(_voices.size()):
			var candidate := _voices[(_next_voice + offset) % _voices.size()]
			if not candidate.playing:
				player = candidate
				break
		if player == null: player = _voices[_next_voice % _voices.size()]
		_next_voice += 1
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = gain
	player.play()
	_voice_kind[player.get_instance_id()] = kind
	_last_play[cue] = _clock
	cue_played.emit(cue)
	return true

func _stop_one_shots() -> void:
	for player in _voices: player.stop()
	for player in _ui_voices: player.stop()

func get_cue_player(_cue: StringName) -> AudioStreamPlayer:
	return null

func _exit_tree() -> void:
	_stop_one_shots()
	for player in _voices + _ui_voices: player.stream = null
	_cache.clear()

# ---------------------------------------------------------------- synthesis

func _stream(cue: StringName) -> AudioStreamWAV:
	if _cache.has(cue): return _cache[cue]
	var samples := _synth(String(cue))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in range(samples.size()):
		bytes.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	_cache[cue] = stream
	return stream

func _buffer(seconds: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(int(seconds * RATE))
	return buffer

## Decaying tone with optional pitch glide, partials and noise transient.
func _hit(buffer: PackedFloat32Array, start: float, f0: float, f1: float, decay: float, gain: float,
		partial := 0.0, noise := 0.0, noise_decay := 0.004, wobble := 0.0, seed_value := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phase := 0.0
	var phase2 := 0.0
	var first := int(start * RATE)
	var length := buffer.size() - first
	var lp := 0.0
	for index in range(maxi(0, length)):
		var t := float(index) / RATE
		var glide := f1 + (f0 - f1) * exp(-t / maxf(decay * 0.6, 0.001))
		var vibrato := 1.0 + wobble * sin(TAU * 7.0 * t)
		phase += TAU * glide * vibrato / RATE
		phase2 += TAU * glide * 2.01 * vibrato / RATE
		var env := exp(-t / decay) * minf(1.0, t * RATE / 24.0)
		var s := sin(phase) + partial * sin(phase2)
		var n := 0.0
		if noise > 0.0:
			lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.5
			n = lp * noise * exp(-t / noise_decay)
		buffer[first + index] += (s * env + n) * gain

func _note(buffer: PackedFloat32Array, start: float, frequency: float, length: float, gain: float, bright := 0.4) -> void:
	var first := int(start * RATE)
	var count := mini(int(length * RATE), buffer.size() - first)
	for index in range(maxi(0, count)):
		var t := float(index) / RATE
		var env := exp(-t / (length * 0.45)) * minf(1.0, t * RATE / 60.0)
		var s := sin(TAU * frequency * t) + bright * sin(TAU * frequency * 2.0 * t) * exp(-t / 0.05) + 0.15 * sin(TAU * frequency * 3.0 * t)
		buffer[first + index] += s * env * gain

func _sweep(buffer: PackedFloat32Array, start: float, length: float, f0: float, f1: float, gain: float, square := false) -> void:
	var first := int(start * RATE)
	var count := mini(int(length * RATE), buffer.size() - first)
	var phase := 0.0
	for index in range(maxi(0, count)):
		var p := float(index) / float(maxi(1, count))
		phase += TAU * lerpf(f0, f1, p) / RATE
		var env := sin(PI * p)
		var s := sin(phase)
		if square: s = clampf(s * 3.0, -1.0, 1.0) * 0.6
		buffer[first + index] += s * env * gain

func _whoosh(buffer: PackedFloat32Array, start: float, length: float, gain: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var first := int(start * RATE)
	var count := mini(int(length * RATE), buffer.size() - first)
	var lp := 0.0
	for index in range(maxi(0, count)):
		var p := float(index) / float(maxi(1, count))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * lerpf(0.05, 0.25, p)
		buffer[first + index] += lp * sin(PI * p) * gain

const SCALE := [0, 2, 4, 7, 9]

func _midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)

func _synth(cue: String) -> PackedFloat32Array:
	if cue.begins_with("impact_"):
		var tier := int(cue.trim_prefix("impact_"))
		var b := _buffer([0.06, 0.08, 0.11, 0.11, 0.12, 0.16, 0.18, 0.32, 0.30, 0.38][tier])
		match tier:
			0: _hit(b, 0, 2600, 2300, 0.010, 0.55, 0.2, 0.5, 0.002)              # 탁구공 '똑'
			1: _hit(b, 0, 1900, 1700, 0.016, 0.55, 0.5, 0.9, 0.003, 0.0, 2)       # 골프공 '딱'
			2: _hit(b, 0, 560, 470, 0.028, 0.55, 0.2, 0.6, 0.010, 0.0, 3)         # 테니스공(펠트)
			3: _hit(b, 0, 420, 360, 0.030, 0.60, 0.4, 0.5, 0.005, 0.0, 4)         # 야구공
			4: _hit(b, 0, 330, 290, 0.034, 0.60, 0.35, 0.45, 0.006, 0.0, 5)       # 소프트볼
			5: _hit(b, 0, 260, 200, 0.050, 0.60, 0.25, 0.25, 0.008, 0.0, 6)       # 배구공
			6: _hit(b, 0, 190, 130, 0.060, 0.70, 0.3, 0.3, 0.008, 0.0, 7)         # 축구공
			7:                                                                     # 농구공 '퉁'
				_hit(b, 0, 150, 82, 0.110, 0.85, 0.15, 0.25, 0.006, 0.0, 8)
				_hit(b, 0, 240, 210, 0.070, 0.18, 0.0)
			8: _hit(b, 0, 110, 68, 0.120, 0.80, 0.1, 0.15, 0.010, 0.08, 9)        # 짐볼(말랑)
			9:                                                                     # 비치볼 '뽀옹'
				_hit(b, 0, 300, 520, 0.140, 0.55, 0.1, 0.0, 0.004, 0.05, 10)
		return b
	if cue.begins_with("merge_"):
		var tier := int(cue.trim_prefix("merge_"))
		var notes := 2 + tier / 2
		var step := 0.065 - float(tier) * 0.002
		var b := _buffer(step * notes + 0.35 + float(tier) * 0.02)
		var root := 67.0 + float(tier) * 2.0
		for index in range(notes):
			var degree: int = SCALE[index % SCALE.size()] + 12 * (index / SCALE.size())
			_note(b, step * index, _midi(root + degree), 0.22 + float(tier) * 0.015, 0.32, 0.3 + float(tier) * 0.05)
		if tier >= 5:
			# Sparkle on high tiers.
			for index in range(tier - 3):
				_note(b, step * notes * 0.5 + 0.03 * index, _midi(root + 24 + SCALE[index % 5]), 0.12, 0.10, 0.6)
		return b
	match cue:
		"drop":
			var b := _buffer(0.12)
			_whoosh(b, 0, 0.11, 0.35)
			_hit(b, 0, 700, 520, 0.020, 0.15)
			return b
		"wall":
			var b := _buffer(0.06)
			_hit(b, 0, 700, 600, 0.012, 0.3, 0.0, 0.4, 0.004)
			return b
		"danger":
			var b := _buffer(0.42)
			_sweep(b, 0.0, 0.16, 880, 860, 0.30, true)
			_sweep(b, 0.21, 0.16, 660, 640, 0.30, true)
			return b
		"game_over":
			var b := _buffer(1.2)
			var notes := [72, 67, 64, 60]
			for index in range(notes.size()):
				_note(b, 0.18 * index, _midi(notes[index]), 0.45 if index < 3 else 0.7, 0.36, 0.2)
			return b
		"final":
			var b := _buffer(1.6)
			var notes := [60, 64, 67, 72, 76, 79, 84]
			for index in range(notes.size()):
				_note(b, 0.07 * index, _midi(notes[index]), 0.5, 0.25, 0.5)
			for chord in [72, 76, 79, 84]:
				_note(b, 0.55, _midi(chord), 0.9, 0.16, 0.4)
			for index in range(10):
				_note(b, 0.6 + 0.06 * index, _midi(96 + SCALE[index % 5]), 0.12, 0.07, 0.6)
			return b
		"discovery":
			var b := _buffer(0.45)
			_note(b, 0.0, _midi(88), 0.30, 0.22, 0.6)
			_note(b, 0.08, _midi(91), 0.35, 0.22, 0.6)
			return b
		"restart":
			var b := _buffer(0.35)
			for index in range(3): _note(b, 0.07 * index, _midi(72 + SCALE[index * 2 % 5] ), 0.18, 0.25)
			return b
		"ui_open":
			var b := _buffer(0.10)
			_sweep(b, 0, 0.09, 700, 1150, 0.28)
			return b
		"ui_cancel":
			var b := _buffer(0.10)
			_sweep(b, 0, 0.09, 950, 620, 0.26)
			return b
		_:
			var b := _buffer(0.05)
			_hit(b, 0, 1300, 1200, 0.012, 0.35)
			return b
