extends Node2D
## 비치볼 머지 본체: 용기(볼 카트), 투하·합체·게임오버 규칙, 입력, 화면 투영, 일시정지.
const Plush := preload("res://scripts/plushie_body.gd")
const Balls := preload("res://data/balls.gd")
const HUD := preload("res://scripts/plushie_hud.gd")
const Audio := preload("res://scripts/game_audio.gd")
const Routes := preload("res://scripts/core/routes.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Localization := preload("res://scripts/core/localization.gd")
const Session := preload("res://scripts/core/session.gd")
const Stages := preload("res://data/stages/registry.gd")
const Leaderboard := preload("res://scripts/score/leaderboard.gd")
const BestScore := preload("res://scripts/score/best_score.gd")
const Tweaks := preload("res://scripts/tuning/tweak_service.gd")
const Feedback := preload("res://scripts/vfx/feedback.gd")
const BoardInk := preload("res://scripts/vfx/board_ink.gd")
const CartArt := preload("res://scripts/vfx/cart_art.gd")
const DeviceLayout := preload("res://scripts/core/device_layout.gd")
const StorageMigration := preload("res://scripts/core/storage_migration.gd")

## 용기 내부: 가로 600 × 세로 780 (1:1.3).
const TANK := Rect2(60, 240, Balls.CONTAINER_WIDTH, Balls.CONTAINER_WIDTH * Balls.CONTAINER_RATIO)
const EXTRA_PILE_DEPTH := 0.0
## 볼 카트 전체(손잡이·바퀴 포함) — 화면에 맞출 때 쓰는 영역.
const CABINET := Rect2(8, 44, 704, 1072)
const HOLD_Y := 150.0
const DANGER_Y := 312.0
const OVERFLOW_SECONDS := 2.0
const DANGER_GRACE_SECONDS := 1.0
const MAX_TOYS := 90

enum ClawState { HOLDING, OPENING, RELOADING }
var routes := Routes.new()
var settings := Settings.new()
var locale := Localization.new()
var session := Session.new()
var leaderboard := Leaderboard.new()
var best := BestScore.new()
var _sandbox_run := false
var tweaks := Tweaks.new(Tweaks.owner_build())
var device := DeviceLayout.new()
var audio: GameAudio
var feedback: Node2D
var _hud: Control
var _ink: Node2D
var stage_index := 0
var claw_state := ClawState.HOLDING
var claw_timer := 0.0
var claw_openness := 0.0
var held_toy: PlushieBody
var held_tier := 0
var next_tier := 0
var aim_x := 360.0
var discovered: Array[bool] = []
var overflow_time := 0.0
var danger_warning := false
var danger_armed := true
var new_best := false
var _impact_cooldown := 0.0
var _impact_window := 0.0
var _impact_count := 0
var _run_generation := 0
var _recorded := false
var _confirm_action := ""
var _aim_touch_index := -1
var _mouse_drop_armed := false
var _input_guard := 0.0
var input_method := "keyboard"
var error_key := "error.stage"
var active_open_seconds := 0.05
var active_reload_seconds := 0.45
var board_screen_rect := Rect2()
var tank_rect := TANK
var _walls: Array[StaticBody2D] = []
var held_axis := 0.0
var _base_transform := Transform2D.IDENTITY
var _shake_time := 0.0
var _shake_strength := 0.0
var _clock := 0.0
var _device_callback: JavaScriptObject
var _touch_cancel_callback: JavaScriptObject
var _viewport_updating := false
var _screen_size := Vector2i.ZERO
var _resize_ended := false
var _resize_banner: CanvasLayer
var _multiplayer_screen: Control
var _multiplayer_layer: CanvasLayer

var score: int:
    get: return session.score.total
var best_score: int:
    get: return best.value
var drop_count: int:
    get: return session.drops
var merge_count: int:
    get: return session.merges
var is_paused: bool:
    get: return routes.modal() == "pause"
var show_help: bool:
    get: return routes.modal() == "help"
var is_game_over: bool:
    get: return routes.route == "debrief"
var audio_muted: bool:
    get: return bool(settings.values.muted)

func _ready() -> void:
    StorageMigration.run()
    device.refresh(get_viewport_rect().size)
    if device.mobile: input_method = "touch"
    if OS.has_feature("web"): DeviceLayout.apply_window_scale(get_window(),device.css_viewport)
    if OS.has_feature("android") or OS.has_feature("ios"):
        DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
    discovered.resize(Balls.count())
    discovered.fill(false)
    settings.load_data()
    settings.values.locale = "ko"
    locale.locale = "ko"
    TranslationServer.set_locale("ko")
    leaderboard.load_data()
    best.load_data()
    _create_walls()
    feedback = Feedback.new()
    feedback.bounds = tank_rect
    feedback.font = locale.font_for_weight(700)
    feedback.z_index = 8
    add_child(feedback)
    _ink = BoardInk.new()
    _ink.game = self
    _ink.z_index = 7
    add_child(_ink)
    audio = Audio.new()
    audio.muted = audio_muted
    add_child(audio)
    var layer := CanvasLayer.new()
    layer.layer = 20
    add_child(layer)
    _hud = HUD.new()
    _hud.game = self
    layer.add_child(_hud)
    _resize_banner = preload("res://scripts/ui/resize_banner.gd").new()
    _resize_banner.font = locale.font_for_weight(700)
    _resize_banner.message = t("ui.resize_ended")
    add_child(_resize_banner)
    reset_resize_guard()
    routes.changed.connect(_route_changed)
    tweaks.changed.connect(_apply_presentation)
    get_viewport().size_changed.connect(_viewport_changed)
    _apply_presentation()
    _route_changed()
    if OS.has_feature("web"):
        _device_callback = JavaScriptBridge.create_callback(_browser_device_changed)
        JavaScriptBridge.get_interface("window").mushiesDeviceChanged = _device_callback
        _touch_cancel_callback = JavaScriptBridge.create_callback(_browser_touch_cancelled)
        JavaScriptBridge.get_interface("window").mushiesTouchCancelled = _touch_cancel_callback

func _browser_device_changed(_arguments: Array) -> void:
    _viewport_changed()

func _browser_touch_cancelled(_arguments: Array) -> void:
    # Godot Web maps touchcancel to a normal release. Clear gesture ownership
    # from the browser capture phase before that release reaches gameplay.
    _aim_touch_index = -1
    if multiplayer_active() and is_instance_valid(_multiplayer_screen.local_board):
        _multiplayer_screen.local_board.cancel_touch()

func t(key: String, values: Dictionary = {}) -> String:
    return locale.t(key, values)

func toy_name(tier: int) -> String:
    return Balls.name_of(tier)

func is_frozen() -> bool:
    return routes.frozen() or device.portrait_blocked

func _viewport_changed() -> void:
    if _viewport_updating: return
    _viewport_updating = true
    var was_mobile := device.mobile
    device.refresh(get_viewport_rect().size)
    var next_size := _measured_screen_size()
    var changed := _screen_size != Vector2i.ZERO and next_size != _screen_size
    _screen_size = next_size
    if changed: _end_for_resize()
    if device.mobile and not was_mobile: input_method = "touch"
    if OS.has_feature("web"): DeviceLayout.apply_window_scale(get_window(),device.css_viewport)
    if device.portrait_blocked:
        _aim_touch_index = -1
        held_axis = 0
    if multiplayer_active():
        # The local duel owns its fixed arena projection.
        get_viewport().canvas_transform = Transform2D.IDENTITY
        _multiplayer_screen.set_app_visible(device.app_visible)
        _multiplayer_screen.on_device_changed()
        _viewport_updating = false
        return
    _hud.rebuild()
    _route_changed()
    _viewport_updating = false

func _measured_screen_size() -> Vector2i:
    if OS.has_feature("web") and device.css_viewport.x > 0 and device.css_viewport.y > 0:
        return device.css_viewport
    return get_viewport().size

func reset_resize_guard() -> void:
    device.refresh(get_viewport_rect().size)
    _screen_size = _measured_screen_size()
    set_resize_ended(false)

func set_resize_ended(ended: bool) -> void:
    if _resize_ended == ended: return
    _resize_ended = ended
    if is_instance_valid(_resize_banner): _resize_banner.visible = ended and not OS.has_feature("web")
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.mushiesSetResizeEnded?.("+JSON.stringify(ended)+")",true)

func _end_for_resize() -> void:
    if multiplayer_active():
        _multiplayer_screen.end_for_resize()
        return
    if routes.route != "gameplay" or session.outcome != "": return
    _aim_touch_index = -1
    held_axis = 0
    session.finish("defeat","resize")
    set_resize_ended(true)
    _finish_run()

func reduced_motion() -> bool:
    return settings.values.reduced_motion or tweaks.value("ui.reduced_motion")

## HUD가 정한 화면 영역에 볼 카트를 비율 그대로 맞춰 넣습니다.
func project_board(rect: Rect2) -> void:
    if rect.size.x <= 0 or rect.size.y <= 0: return
    var factor := minf(rect.size.x / CABINET.size.x, rect.size.y / CABINET.size.y)
    var size := CABINET.size * factor
    # 엄지가 닿기 쉬운 아래쪽에 붙이고, 남는 공간은 위(하늘)로 둡니다.
    var origin := Vector2(rect.get_center().x - size.x * 0.5, rect.end.y - size.y)
    board_screen_rect = Rect2(origin, size)
    var offset := origin - CABINET.position * factor
    _base_transform = Transform2D(Vector2(factor,0), Vector2(0,factor), offset)
    get_viewport().canvas_transform = _base_transform

func cabinet_bounds() -> Rect2:
    return CABINET

## 화면 좌표 → 월드 좌표.
func screen_to_world(at: Vector2) -> Vector2:
    return _base_transform.affine_inverse() * at

func shake(strength: float, seconds := 0.35) -> void:
    if reduced_motion(): return
    _shake_strength = maxf(_shake_strength, strength)
    _shake_time = maxf(_shake_time, seconds)

func _process(delta: float) -> void:
    if multiplayer_active(): return
    _clock += delta
    _input_guard = maxf(0.0, _input_guard - delta)
    if not is_frozen():
        var axis := Input.get_axis("ui_left", "ui_right") + held_axis
        for pad in Input.get_connected_joypads():
            var stick := Input.get_joy_axis(pad,JOY_AXIS_LEFT_X)
            if absf(stick) > 0.18 and absf(stick) > absf(axis): axis = stick
        if Input.is_key_pressed(KEY_A): axis -= 1
        if Input.is_key_pressed(KEY_D): axis += 1
        if absf(axis) > 0.1:
            tweaks.apply("NEXT_ACTION")
            aim_x += clampf(axis,-1,1) * float(tweaks.value("player.aim.speed")) * delta
            _clamp_aim()
        _advance_claw(delta)
        _impact_cooldown = maxf(0, _impact_cooldown-delta)
        _impact_window = maxf(0, _impact_window-delta)
        if _impact_window <= 0: _impact_count = 0
    if is_instance_valid(held_toy): held_toy.position = Vector2(aim_x,held_y())
    feedback.paused = is_frozen()
    _apply_shake(delta)
    _ink.queue_redraw()

func _apply_shake(delta: float) -> void:
    if routes.route != "gameplay" and routes.route != "debrief": return
    var transform := _base_transform
    if _shake_time > 0.0 and not is_frozen():
        _shake_time = maxf(0.0, _shake_time - delta)
        var amount := _shake_strength * clampf(_shake_time / 0.35, 0.0, 1.0)
        transform.origin += Vector2(sin(_clock * 71.0), cos(_clock * 53.0)) * amount * _base_transform.x.x
        if _shake_time <= 0.0: _shake_strength = 0.0
    get_viewport().canvas_transform = transform

func _physics_process(delta: float) -> void:
    if is_frozen(): return
    session.tick(delta)
    if session.outcome != "":
        _finish_run()
        return
    var maximum := 0.0
    var warning := false
    for toy in get_board_toys():
        if toy.held or toy.destroy_pending or toy.is_queued_for_deletion(): continue
        toy.age += delta
        # 떨어뜨린 지 1초가 안 된 공은 판정에서 제외합니다.
        if toy.age >= DANGER_GRACE_SECONDS and toy.top_y() < danger_y() and not toy.merge_locked:
            toy.danger_time += delta
            warning = true
            maximum = maxf(maximum,toy.danger_time)
        else: toy.danger_time = 0.0
    overflow_time = maximum
    danger_warning = warning
    if warning and danger_armed:
        danger_armed = false
        audio.play_danger()
    elif not warning: danger_armed = true
    if overflow_time >= float(tweaks.value("gameplay.overflow_seconds")):
        session.finish("defeat", "overflow")
    if session.outcome != "": _finish_run()

func danger_y() -> float:
    return float(tweaks.value("environment.danger.line"))

func held_y() -> float:
    return HOLD_Y

func can_drop_now() -> bool:
    return not is_frozen() and session.can_drop() and claw_state == ClawState.HOLDING and is_instance_valid(held_toy)

func request_drop() -> void:
    if is_frozen(): return
    if not session.can_drop() or claw_state != ClawState.HOLDING or not is_instance_valid(held_toy):
        return
    tweaks.apply("NEXT_ACTION")
    active_open_seconds = tweaks.value("player.claw.open_seconds")
    active_reload_seconds = tweaks.value("player.claw.reload_seconds")
    claw_state = ClawState.OPENING
    claw_timer = 0
    _release_held()
    audio.play_drop(held_tier)

func _advance_claw(delta: float) -> void:
    if claw_state == ClawState.OPENING:
        claw_timer += delta
        claw_openness = clampf(claw_timer / maxf(active_open_seconds, 0.001),0,1)
        if claw_timer >= active_open_seconds:
            claw_state = ClawState.RELOADING
            claw_timer = 0
    elif claw_state == ClawState.RELOADING:
        claw_timer += delta
        claw_openness = 1.0-clampf(claw_timer / maxf(active_reload_seconds, 0.001),0,1)
        if claw_timer >= active_reload_seconds and session.can_drop():
            held_tier = session.next_tier()
            next_tier = session.next_tier(1)
            _load_claw()
            claw_state = ClawState.HOLDING
            claw_openness = 0
            claw_timer = 0

func _release_held() -> void:
    if not is_instance_valid(held_toy): return
    held_toy.position = Vector2(aim_x,held_y())
    held_toy.release()
    _mark_seen(held_toy.tier, false)
    held_toy = null
    session.record_drop()

func _load_claw() -> void:
    held_toy = _spawn(held_tier,Vector2(aim_x,HOLD_Y),true)
    if not is_instance_valid(held_toy): return
    held_toy.position.y = held_y()
    _clamp_aim()

func _mark_seen(tier: int, announce: bool) -> void:
    if tier < 0 or tier >= discovered.size(): return
    session.note_tier(tier)
    if discovered[tier]: return
    discovered[tier] = true
    if announce and is_instance_valid(_hud): _hud.announce_new(tier)

func _spawn(tier: int, where: Vector2, held := false) -> PlushieBody:
    if get_board_toys().size() >= MAX_TOYS: return null
    tweaks.apply("NEXT_SPAWN")
    var toy := Plush.new() as PlushieBody
    toy.configure(tier,self)
    toy.position = where
    toy.held = held
    toy.freeze = held
    toy.collision_layer = 0 if held else 1
    toy.collision_mask = 0 if held else 1
    add_child(toy)
    if not held: toy.add_to_group("plushies")
    return toy

func get_board_toys() -> Array[PlushieBody]:
    # SceneTree groups span all viewports, rooms and worlds. Ownership does not.
    var result: Array[PlushieBody] = []
    if not is_inside_tree(): return result
    for node in get_tree().get_nodes_in_group("plushies"):
        if node is PlushieBody and node.manager == self and not node.is_queued_for_deletion():
            result.append(node)
    return result

func _clamp_aim() -> void:
    # 조준 위치는 공이 용기 벽 밖으로 나가지 않게 제한합니다.
    var half := Balls.radius(held_tier) + 2.0
    if is_instance_valid(held_toy): half = held_toy.radius + 2.0
    aim_x = clampf(aim_x,tank_rect.position.x+half,tank_rect.end.x-half)

func request_merge(a: PlushieBody, b: PlushieBody) -> void:
    if is_frozen() or not is_instance_valid(a) or not is_instance_valid(b): return
    if a.manager != self or b.manager != self: return
    if a == b or a.held or b.held or a.merge_locked or b.merge_locked or a.destroy_pending or b.destroy_pending: return
    if a.tier != b.tier: return
    a.merge_locked = true
    b.merge_locked = true
    call_deferred("_merge",a,b,_run_generation)

func _merge(a: PlushieBody,b: PlushieBody,generation: int) -> void:
    if generation != _run_generation: return
    if is_instance_valid(a) and a.manager != self or is_instance_valid(b) and b.manager != self: return
    if not is_instance_valid(a) or not is_instance_valid(b) or a.is_queued_for_deletion() or b.is_queued_for_deletion() or a.destroy_pending or b.destroy_pending:
        for survivor in [a,b]:
            if is_instance_valid(survivor) and not survivor.is_queued_for_deletion() and not survivor.destroy_pending: survivor.merge_locked = false
        return
    if is_frozen():
        a.merge_locked = false
        b.merge_locked = false
        return
    var at := (a.position+b.position)*0.5
    var velocity := (a.linear_velocity+b.linear_velocity)*0.3
    var tier := a.tier + 1
    a.remove_from_group("plushies")
    b.remove_from_group("plushies")
    a.queue_free()
    b.queue_free()
    if a.tier >= Balls.last_tier():
        # 비치볼 + 비치볼: 둘 다 사라지고 보너스와 큰 축하.
        var bonus := session.final_pair()
        feedback.celebrate(at)
        feedback.popup(at, "+%d" % bonus, Color("ffd23f"), 64)
        shake(14.0, 0.6)
        audio.play_victory()
        if is_instance_valid(_hud): _hud.celebrate(bonus)
        return
    var toy := _spawn(tier,at)
    if toy == null: return
    toy.position.x = clampf(at.x,tank_rect.position.x+toy.radius+1,tank_rect.end.x-toy.radius-1)
    toy.position.y = minf(at.y,tank_rect.end.y-toy.radius-1)
    toy.linear_velocity = velocity
    toy.age = DANGER_GRACE_SECONDS * 0.5
    toy.start_pop()
    toy.halo = 0.0 if reduced_motion() else 0.6
    var first := not discovered[tier]
    var points := session.merge(tier)
    _mark_seen(tier, true)
    feedback.burst(toy.position, Balls.main_color(tier), toy.radius)
    feedback.popup(toy.position, "+%d" % points, Color("fffaf0"), 30 + tier * 3)
    if tier >= 7: shake(4.0 + float(tier - 7) * 3.0)
    audio.play_merge(tier,first)
    if session.outcome != "": _finish_run()

func plushie_impact(strength: float,tier := 0,wall := false) -> void:
    if is_frozen() or _impact_cooldown > 0: return
    # 충돌음 제한: 0.25초에 최대 4번.
    if _impact_count >= 4: return
    if strength < 0.18: return
    _impact_count += 1
    if _impact_window <= 0: _impact_window = 0.25
    _impact_cooldown = 0.04
    audio.play_impact(strength,tier,wall)

func _finish_run() -> void:
    if _recorded or session.outcome == "": return
    _recorded = true
    var eligible: bool = session.reason != "resize"
    new_best = eligible and best.submit(session.score.total)
    var result := session.score.finish({"run_id":session.run_id,"name":t("ui.player"),
        "stage":session.stage.id,"stage_index":stage_index,"outcome":session.outcome,
        "timestamp":int(Time.get_unix_time_from_system()),"duration":snappedf(session.elapsed,0.01),
        "config":tweaks.marker(),"eligible":eligible and not tweaks.tainted and not is_sandbox_mode(),"merges":session.merges,
        "reason":session.reason,"goals_reached":session.goals_reached,"highest":session.highest})
    if not is_sandbox_mode(): leaderboard.record(result)
    tweaks.running = false
    audio.set_music_mood(GameAudio.MusicMood.GAME_OVER)
    audio.play_game_over()
    routes.go("debrief")

func start_stage(index := 0, definition: Dictionary = {}) -> bool:
    var stage: Dictionary = definition.duplicate(true) if not definition.is_empty() else Stages.STAGES[clampi(index,0,Stages.STAGES.size()-1)].duplicate(true)
    if not Stages.validate(stage) or not Plush.resources_valid():
        error_key = "error.stage" if not Stages.validate(stage) else "error.assets"
        routes.go("error")
        return false
    _clear_run()
    stage_index = index
    _sandbox_run = tweaks.enabled
    tweaks.begin_run()
    session.start(stage,float(tweaks.value("gameplay.score.multiplier")))
    for record in stage.initial:
        _spawn(record.tier,Vector2(record.x,record.y))
        _mark_seen(record.tier, false)
    held_tier = session.next_tier()
    next_tier = session.next_tier(1)
    _load_claw()
    audio.play_restart()
    _input_guard = 0.2
    routes.go("gameplay")
    reset_resize_guard()
    return true

func restart_game() -> void:
    start_stage(stage_index)

func return_title() -> void:
    if multiplayer_active():
        _close_multiplayer()
        return
    _clear_run()
    tweaks.running = false
    routes.go("title")

func multiplayer_active() -> bool:
    return is_instance_valid(_multiplayer_screen)

func open_multiplayer() -> void:
    if multiplayer_active() or routes.route != "title" or routes.modal() != "": return
    if not device.local_splitscreen_allowed(get_viewport_rect().size): return
    var screen_script = load("res://scripts/multiplayer/multiplayer_screen.gd")
    if screen_script == null: return
    _clear_run()
    _multiplayer_layer = CanvasLayer.new()
    _multiplayer_layer.layer = 40
    add_child(_multiplayer_layer)
    _multiplayer_screen = screen_script.new()
    _multiplayer_screen.game = self
    _multiplayer_screen.closed.connect(_close_multiplayer)
    _hud.sync_routes()
    _hud.hide()
    get_viewport().canvas_transform = Transform2D.IDENTITY
    _multiplayer_layer.add_child(_multiplayer_screen)
    _multiplayer_screen.set_app_visible(device.app_visible)

func _close_multiplayer() -> void:
    set_resize_ended(false)
    if is_instance_valid(_multiplayer_layer): _multiplayer_layer.queue_free()
    _multiplayer_screen = null
    _multiplayer_layer = null
    _hud.show()
    routes.go("title")
    _hud.rebuild()

func _clear_run() -> void:
    set_resize_ended(false)
    _sandbox_run = false
    _run_generation += 1
    for toy in get_board_toys():
        toy.remove_from_group("plushies")
        toy.queue_free()
    if is_instance_valid(held_toy): held_toy.queue_free()
    held_toy = null
    overflow_time = 0
    danger_warning = false
    danger_armed = true
    new_best = false
    claw_state = ClawState.HOLDING
    claw_timer = 0
    claw_openness = 0
    discovered.fill(false)
    aim_x = TANK.get_center().x
    _impact_cooldown = 0
    _impact_count = 0
    held_axis = 0
    _aim_touch_index = -1
    _mouse_drop_armed = false
    _shake_time = 0
    _recorded = false
    feedback.clear()
    audio.clear_transients()

func open_modal(kind: String) -> void:
    if multiplayer_active(): return
    if kind == "help" and (routes.route != "title" or not routes.modal().is_empty()): return
    if kind in ["tweaks", "leaderboard", "share"]: return
    held_axis = 0
    _aim_touch_index = -1
    _hud.dismiss_editor()
    routes.open(kind,get_viewport().gui_get_focus_owner())
    audio.play_ui("open")

func close_modal() -> void:
    _hud.dismiss_editor()
    routes.close()
    _input_guard = 0.2
    audio.play_ui("cancel")

func toggle_pause() -> void:
    if multiplayer_active(): return
    if routes.modal() != "": close_modal()
    elif routes.route == "gameplay": open_modal("pause")

func toggle_help() -> void:
    if multiplayer_active() or routes.route != "title": return
    if routes.modal() == "help": close_modal()
    else: open_modal("help")

func confirm_loss(action: String) -> void:
    if action == "restart": restart_game()
    else: return_title()

func confirm_action() -> void:
    if _confirm_action == "restart": restart_game()
    else: return_title()

func toggle_audio() -> void:
    setting("muted",not audio_muted)
    if not audio_muted: audio.play_ui("toggle")

func setting(key: String, value: Variant) -> void:
    if key == "locale": return
    settings.set_value(key,value)
    _apply_presentation()

func _apply_presentation() -> void:
    if not is_instance_valid(audio): return
    audio.apply_settings(settings.values, tweaks.active)
    feedback.reduced_motion = reduced_motion()
    if reduced_motion():
        feedback.particles.clear()
        for toy in get_board_toys():
            toy.visual_scale = Vector2.ONE
            toy.halo = 0
            toy.queue_redraw()
    feedback.intensity = tweaks.value("environment.particles")
    feedback.ambient = tweaks.value("environment.ambient")
    if is_instance_valid(_hud): _hud.apply_presentation()

func _route_changed() -> void:
    var freeze_now := is_frozen()
    Input.set_default_cursor_shape(Input.CURSOR_ARROW)
    for toy in get_board_toys(): toy.freeze = freeze_now
    visible = routes.route == "gameplay" or routes.route == "debrief"
    if routes.route != "debrief":
        audio.set_music_mood(GameAudio.MusicMood.DUCKED if freeze_now else GameAudio.MusicMood.ACTIVE)
    feedback.paused = freeze_now
    _aim_touch_index = -1
    _mouse_drop_armed = false
    _hud.sync_routes()

func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_IN,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
        device.app_visible = what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_WM_WINDOW_FOCUS_IN]
        if multiplayer_active():
            _multiplayer_screen.set_app_visible(device.app_visible)
            return
    if multiplayer_active(): return
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not is_frozen(): open_modal("pause")

func _input(event: InputEvent) -> void:
    if multiplayer_active(): return
    if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1: return
    if event is InputEventScreenTouch or event is InputEventScreenDrag: input_method = "touch"
    elif event is InputEventJoypadButton or event is InputEventJoypadMotion: input_method = "gamepad"
    elif event is InputEventKey: input_method = "keyboard"
    elif event is InputEventMouseButton or event is InputEventMouseMotion: input_method = "pointer"
    # 브라우저 자동재생 정책: 첫 터치/클릭/키 입력 뒤에만 소리를 냅니다.
    if is_instance_valid(audio) and event.is_pressed(): audio.unlock()

func _in_play_area(at: Vector2) -> bool:
    return board_screen_rect.has_point(at) and not _hud.blocks_pointer(at)

func _unhandled_input(event: InputEvent) -> void:
    if multiplayer_active(): return
    # Emulated mouse input serves native UI controls; the original touch owns play.
    if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1: return
    if event is InputEventKey and event.pressed and not event.echo:
        input_method = "keyboard"
        if event.keycode == KEY_ESCAPE or event.keycode == KEY_P: toggle_pause()
        elif event.keycode == KEY_M: toggle_audio()
        elif event.keycode in [KEY_SPACE,KEY_ENTER] and routes.modal() == "" and routes.route == "gameplay":
            request_drop()
            get_viewport().set_input_as_handled()
    elif event is InputEventJoypadButton and event.pressed:
        input_method = "gamepad"
        if event.button_index == JOY_BUTTON_START: toggle_pause()
        elif event.button_index == JOY_BUTTON_A and not is_frozen(): request_drop()
        elif event.button_index == JOY_BUTTON_B and routes.modal() != "": close_modal()
    elif event is InputEventJoypadMotion: input_method = "gamepad"
    elif event is InputEventMouseMotion and not is_frozen():
        input_method = "pointer"
        if _in_play_area(event.position):
            Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
            _aim_pointer(event.position)
        else: Input.set_default_cursor_shape(Input.CURSOR_ARROW)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        input_method = "pointer"
        # 누름과 뗌이 모두 게임 영역 안이어야 투하합니다(버튼 클릭은 GUI가 먼저 가져감).
        if event.pressed:
            _mouse_drop_armed = not is_frozen() and _input_guard <= 0.0 and _in_play_area(event.position)
            if _mouse_drop_armed:
                _aim_pointer(event.position)
                request_drop()
                _mouse_drop_armed = false
    elif event is InputEventScreenTouch:
        input_method = "touch"
        if event.pressed:
            if _aim_touch_index < 0 and not is_frozen() and _input_guard <= 0.0 and _in_play_area(event.position):
                _aim_touch_index = event.index
                _aim_pointer(event.position)
        elif event.index == _aim_touch_index:
            # 모바일: 손을 떼면 떨어집니다.
            _aim_touch_index = -1
            if not is_frozen() and not event.canceled:
                request_drop()
    elif event is InputEventScreenDrag and not is_frozen() and event.index == _aim_touch_index:
        input_method = "touch"
        _aim_pointer(event.position)

func _aim_pointer(at: Vector2) -> void:
    aim_x = screen_to_world(at).x
    _clamp_aim()

func _create_walls() -> void:
    for index in range(3):
        var wall := StaticBody2D.new()
        wall.add_to_group("cabinet_walls" if index < 2 else "cabinet_floor")
        wall.physics_material_override = PhysicsMaterial.new()
        wall.physics_material_override.bounce = Balls.PHYSICS_WALL_BOUNCE
        wall.physics_material_override.friction = 0.8
        var collision := CollisionShape2D.new()
        collision.shape = RectangleShape2D.new()
        wall.add_child(collision)
        add_child(wall)
        _walls.append(wall)
    _update_walls()

func _update_walls() -> void:
    var top := tank_rect.position.y - 420.0
    var height := tank_rect.end.y - top + 40.0
    var rects := [Rect2(tank_rect.position.x-40,top,40,height),
        Rect2(tank_rect.end.x,top,40,height),
        Rect2(tank_rect.position.x-40,tank_rect.end.y,tank_rect.size.x+80,40)]
    for index in range(_walls.size()):
        _walls[index].position = rects[index].get_center()
        _walls[index].get_child(0).shape.size = rects[index].size

func _draw() -> void:
    CartArt.draw_cart(self, tank_rect)

func _exit_tree() -> void:
    if OS.has_feature("web"):
        JavaScriptBridge.get_interface("window").mushiesDeviceChanged = null
        JavaScriptBridge.get_interface("window").mushiesTouchCancelled = null
    get_viewport().canvas_transform = Transform2D.IDENTITY

func is_sandbox_mode() -> bool:
    return tweaks.enabled or _sandbox_run

func leaderboard_available() -> bool:
    return false
