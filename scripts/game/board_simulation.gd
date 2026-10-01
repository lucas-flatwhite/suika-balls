extends "res://scripts/plushie_main.gd"
## Authoritative duel board. Each instance belongs to its own SubViewport World2D.
## Reuses the shipping ball physics, drop, merge and scoring rules.
## Presentation, local input, persistence and the solo timer are intentionally absent.

class DuelSession extends "res://scripts/core/session.gd":
    func tick(delta: float) -> void:
        if outcome == "": elapsed += maxf(0.0,delta)

    func time_budget() -> float:
        # The match owns one clock for both players; goals never extend a duel.
        return 180.0

class SilentAudio extends "res://scripts/game_audio.gd":
    func _ready() -> void:
        muted = true
        set_process(false)

    func set_music_mood(_mood: MusicMood) -> void:
        pass

var _active := false
var _next_toy_id := 1

func _ready() -> void:
    session = DuelSession.new()
    tweaks = Tweaks.new(false)
    discovered.resize(Balls.count())
    discovered.fill(false)
    tank_rect = TANK
    _create_walls()
    # These inert owners let shared merge/drop code call its usual presentation
    # hooks without creating any AudioStreamPlayers or writing local preferences.
    audio = SilentAudio.new()
    add_child(audio)
    feedback = Feedback.new()
    feedback.reduced_motion = true
    feedback.ambient = false
    feedback.set_process(false)
    add_child(feedback)
    visible = false
    set_process(false)
    set_process_input(false)
    set_process_unhandled_input(false)

func start_duel(seed_value: int) -> void:
    stop()
    _clear_run()
    _next_toy_id = 1
    var definition: Dictionary = Stages.STAGES[0].duplicate(true)
    definition.id = "duel"
    definition.seed = seed_value
    definition.time_limit = 180.0
    session.start(definition,1.0)
    for record in definition.initial:
        _spawn(record.tier,Vector2(record.x,record.y+EXTRA_PILE_DEPTH))
        discovered[record.tier] = true
    held_tier = session.next_tier()
    next_tier = session.next_tier(1)
    _load_claw()
    set_active(true)

func apply_input(aim: float,drop: bool) -> void:
    if is_frozen() or not is_finite(aim): return
    aim_x = aim
    _clamp_aim()
    if is_instance_valid(held_toy): held_toy.position = Vector2(aim_x,held_y())
    if drop: request_drop()

func set_active(value: bool) -> void:
    _active = value and not session.stage.is_empty() and session.outcome == ""
    for toy in get_board_toys(): toy.freeze = not _active
    if is_instance_valid(held_toy): held_toy.freeze = true

func stop() -> void:
    set_active(false)

func is_frozen() -> bool:
    return not _active or session.outcome != ""

func reduced_motion() -> bool:
    return true

func _process(_delta: float) -> void:
    pass

func _physics_process(delta: float) -> void:
    if is_frozen(): return
    _advance_claw(delta)
    if is_instance_valid(held_toy): held_toy.position = Vector2(aim_x,held_y())
    super._physics_process(delta)

func _spawn(tier: int,where: Vector2,held := false) -> PlushieBody:
    var toy := super._spawn(tier,where,held)
    if toy != null:
        toy.set_meta("duel_id",_next_toy_id)
        _next_toy_id += 1
        toy.set_process(false)
    return toy

func snapshot() -> Dictionary:
    var toys: Array[Dictionary] = []
    for toy in get_board_toys():
        if not toy.destroy_pending: toys.append(_toy_snapshot(toy))
    var result := {
        "score":score,"overflow":overflow_time,"outcome":session.outcome,
        "reason":session.reason,"aim_x":aim_x,"claw_openness":claw_openness,
        "held_tier":held_tier,"next_tier":next_tier,
        "tank":[tank_rect.position.x,tank_rect.position.y,tank_rect.size.x,tank_rect.size.y],
        "danger_y":danger_y(),"overflow_seconds":float(tweaks.value("gameplay.overflow_seconds")),
        "toys":toys,"drops":session.drops,"merges":session.merges,"goals":session.goals_reached,
        "elapsed":session.elapsed,"can_drop":not is_frozen() and claw_state == ClawState.HOLDING and is_instance_valid(held_toy)
    }
    if is_instance_valid(held_toy): result.held = _toy_snapshot(held_toy)
    return result

func _toy_snapshot(toy: PlushieBody) -> Dictionary:
    var state := {
        "id":int(toy.get_meta("duel_id",0)),"tier":toy.tier,
        "x":toy.position.x,"y":toy.position.y,"rotation":toy.rotation,
        "radius":toy.radius,
        "vx":toy.linear_velocity.x,"vy":toy.linear_velocity.y
    }
    return state

func _finish_run() -> void:
    # Duel outcomes belong to the local match, never the solo leaderboard.
    _recorded = true
    stop()

func _notification(_what: int) -> void:
    pass

func _input(_event: InputEvent) -> void:
    pass

func _unhandled_input(_event: InputEvent) -> void:
    pass

func _draw() -> void:
    pass

func _exit_tree() -> void:
    # Never touch window state, browser callbacks or the client's cursor here.
    pass
