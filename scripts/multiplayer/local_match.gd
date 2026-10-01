extends Node
## Two in-process authoritative boards with immutable presentation snapshots.
signal state_changed(next: Dictionary)

const Protocol = preload("res://scripts/multiplayer/protocol.gd")
const Board = preload("res://scripts/game/board_simulation.gd")

var countdown_seconds := Protocol.COUNTDOWN_SECONDS
var match_seconds := Protocol.MATCH_SECONDS
# Zero selects a fresh random supply; a positive value supports reproducible rounds.
var seed_value := 0
var player_name := ""
var boards: Array = []
var viewports: Array = []
var state: Dictionary = _empty_state()

var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _starts_at := 0.0
var _ends_at := 0.0
var _snapshot_accumulator := 0.0
var _tick := 0
var _sequences := [0, 0]

static func _empty_state() -> Dictionary:
	return {"status": "idle", "connected": false, "room_code": "", "queue_mode": "local", "player_id": 1,
		"players": [], "boards": [], "countdown": 0.0, "remaining_seconds": Protocol.MATCH_SECONDS,
		"winner_id": 0, "result_reason": "", "match_epoch": 0, "tick": 0,
		"rtt_ms": -1.0, "snapshot_age_ms": 0.0}

func _ready() -> void:
	_rng.randomize()
	set_physics_process(false)

func start_match() -> void:
	if not is_inside_tree() or state.status in ["countdown", "playing"]:
		return
	_start_countdown()

func set_player_name(value: String) -> String:
	player_name = Protocol.normalize_player_name(value)
	for player in state.players:
		if int(player.id) == 1:
			player.name = player_name
	if not state.players.is_empty():
		state_changed.emit(state.duplicate(true))
	return player_name

func send_input(player_id: int, aim_x: float, drop: bool = false) -> void:
	if state.status != "playing" or player_id not in [1, 2] or not is_finite(aim_x):
		return
	var slot := player_id - 1
	_sequences[slot] += 1
	boards[slot].apply_input(clampf(aim_x, Protocol.AIM_MIN, Protocol.AIM_MAX), drop)

func request_rematch() -> void:
	if state.status == "finished":
		_start_countdown()

func end_for_resize() -> void:
	if state.status not in ["countdown","playing"]: return
	_finish(-1,"resize")

func stop() -> void:
	set_physics_process(false)
	_clear_boards()
	_elapsed = 0.0
	_snapshot_accumulator = 0.0
	_tick = 0
	state = _empty_state()
	state.remaining_seconds = maxf(0.0, match_seconds)
	state_changed.emit(state.duplicate(true))

func _start_countdown() -> void:
	_clear_boards()
	_elapsed = 0.0
	_starts_at = maxf(0.0, countdown_seconds)
	_ends_at = _starts_at + maxf(0.0, match_seconds)
	_snapshot_accumulator = 0.0
	_tick = 0
	_sequences = [0, 0]
	var epoch := int(state.match_epoch) + 1
	state = _empty_state()
	state.status = "countdown"
	state.match_epoch = epoch
	state.players = [{"id": 1, "name": player_name, "ready": true, "rematch": false}, {"id": 2, "name": "", "ready": true, "rematch": false}]
	var supply_seed := seed_value if seed_value > 0 else _rng.randi_range(1, 2147483646)
	for player_id in [1, 2]:
		var viewport := SubViewport.new()
		viewport.name = "LocalPlayer%d" % player_id
		viewport.size = Vector2i(1440, 900)
		viewport.world_2d = World2D.new()
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		get_tree().root.add_child(viewport)
		var board := Board.new()
		viewport.add_child(board)
		board.start_duel(supply_seed)
		board.set_active(false)
		viewports.append(viewport)
		boards.append(board)
	set_physics_process(true)
	_publish_state()

func _physics_process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	_tick += 1
	if state.status == "countdown" and _elapsed >= _starts_at:
		state.status = "playing"
		_ends_at = _elapsed + maxf(0.0, match_seconds)
		for board in boards:
			board.set_active(true)
		_publish_state()
	elif state.status == "playing":
		var a: Dictionary = boards[0].snapshot()
		var b: Dictionary = boards[1].snapshot()
		var a_lost := str(a.get("outcome", "")) == "defeat"
		var b_lost := str(b.get("outcome", "")) == "defeat"
		if (a_lost and b_lost) or _elapsed >= _ends_at:
			var score_a := int(a.get("score", 0))
			var score_b := int(b.get("score", 0))
			_finish(-1 if score_a == score_b else (1 if score_a > score_b else 2), "overflow" if a_lost and b_lost else "time")
			return
	_snapshot_accumulator += delta
	if _snapshot_accumulator >= 1.0 / Protocol.SNAPSHOT_HZ:
		_snapshot_accumulator = fmod(_snapshot_accumulator, 1.0 / Protocol.SNAPSHOT_HZ)
		_publish_state()

func _finish(winner_id: int, reason: String) -> void:
	state.status = "finished"
	state.winner_id = winner_id
	state.result_reason = reason
	state.remaining_seconds = clampf(_ends_at - _elapsed, 0.0, maxf(0.0, match_seconds))
	for board in boards:
		board.stop()
	set_physics_process(false)
	_publish_state()

func _publish_state() -> void:
	var snapshots: Array = []
	for slot in range(boards.size()):
		var snapshot: Dictionary = boards[slot].snapshot()
		snapshot.player_id = slot + 1
		snapshot.ack_seq = int(_sequences[slot])
		snapshots.append(snapshot)
	state.boards = snapshots
	state.countdown = maxf(0.0, _starts_at - _elapsed) if state.status == "countdown" else 0.0
	if state.status == "countdown":
		state.remaining_seconds = maxf(0.0, match_seconds)
	elif state.status == "playing":
		state.remaining_seconds = maxf(0.0, _ends_at - _elapsed)
	state.tick = _tick
	state_changed.emit(state.duplicate(true))

func _clear_boards() -> void:
	for board in boards:
		if is_instance_valid(board):
			board.stop()
	for viewport in viewports:
		if is_instance_valid(viewport):
			viewport.queue_free()
	boards.clear()
	viewports.clear()

func _exit_tree() -> void:
	_clear_boards()
