extends SceneTree
var game: Node
var assertions := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
    assertions += 1
    if not value: failures.append(message); push_error(message)
func settle() -> void:
    for frame in range(4): await process_frame
func resize_to(size: Vector2i) -> void:
    root.size = size
    game._viewport_changed()
func run() -> void:
    root.size = Vector2i(1440,900)
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await settle()
    game.audio.set_muted(true)
    game.tweaks.reset_all()
    game.tweaks.enabled = false
    game.leaderboard.path = "user://resize-test-leaderboard.json"
    game.leaderboard.rows.clear()
    game.device.force_mobile = 0
    resize_to(Vector2i(1280,800))
    check(game.routes.route == "title" and not game._resize_ended,"Title resizing never ends an unstarted game")
    check(game.start_stage(0),"Solo starts after title resizing")
    var run_id: String = game.session.run_id
    game._viewport_changed()
    game.device.app_visible = false
    game._viewport_changed()
    check(game.session.outcome.is_empty(),"Same-size/visibility-only notifications do not end the run")
    game.device.app_visible = true
    var toy = game._spawn(0,Vector2(700,600))
    game.session.score.award("merge",3)
    game._aim_touch_index = 2
    game.held_axis = 1.0
    var merge_peer = game._spawn(0,Vector2(900,600))
    var bomb = game._spawn(game.BombDefinition.TIER,Vector2(500,600))
    game.request_merge(toy,merge_peer)
    game.request_bomb_detonation(bomb,[])
    root.size = Vector2i(1200,800)
    await process_frame
    check(game.session.reason == "resize" and game.session.outcome == "defeat" and game.routes.route == "debrief","Real resize immediately ends solo through the normal result path")
    check(is_instance_valid(toy) and is_instance_valid(merge_peer) and is_instance_valid(bomb) and game.session.merges == 0,"Queued merge/bomb work cannot mutate a run after the actual resize signal")
    check(game._resize_ended and game._resize_banner.visible,"Resize shows persistent native banner")
    check(game._resize_banner.label.text == "CHEATER CHEATER, PANTS ON FIRE","Banner has exact requested message")
    check(game._resize_banner.label.get_theme_font("font") == game.locale.font_for_weight(700),"Banner resolves to the established CC0 font")
    check(game._aim_touch_index == -1 and is_zero_approx(game.held_axis) and toy.freeze,"Resize cancels held input and freezes actors immediately")
    check(not game.session.score.result().eligible and game.leaderboard.rows.is_empty(),"Resize results are ineligible and never saved to standings")
    var result: Dictionary = game.session.score.result()
    var elapsed: float = game.session.elapsed
    var drops: int = game.drop_count
    game.request_drop(); game._advance_claw(1); game._physics_process(1)
    game.session.score.award("merge",10)
    resize_to(Vector2i(1100,800))
    game._viewport_changed()
    check(game.session.score.result() == result and game.session.elapsed == elapsed and game.drop_count == drops,"Repeated resize, input and ticks cannot change the finalized result")
    check(game.start_stage(0) and game.session.run_id != run_id and not game._resize_ended,"Restart clears banner and establishes a fresh baseline")
    game.open_modal("pause")
    game.open_modal("settings")
    resize_to(Vector2i(1000,760))
    check(game.session.reason == "resize" and game.routes.stack.is_empty() and game.routes.route == "debrief","Resizing a paused run closes nested menus and ends it immediately")
    game.return_title()
    check(not game._resize_ended,"Title clears the completed-run banner")
    resize_to(Vector2i(1440,900))
    game.open_multiplayer()
    await settle()
    var screen: Control = game._multiplayer_screen
    resize_to(Vector2i(1400,900))
    check(screen.phase == "idle" and not game._resize_ended,"Same-device lobby resizing does not invent a match result")
    screen._start_local()
    check(screen.local_match.state.status == "countdown","Local fixture starts in countdown")
    resize_to(Vector2i(1360,900))
    check(screen.local_match.state.status == "finished" and screen.state.result_reason == "resize" and game._resize_ended,"Resize ends same-device countdown immediately")
    check(not screen.local_match.is_physics_processing() and not screen._can_play(),"Ended duel stops authority processing and input")
    for board in screen.local_match.boards: check(not board._active,"Both local boards stop on resize")
    screen._rematch()
    screen.local_match._physics_process(4)
    check(screen.local_match.state.status == "playing" and not game._resize_ended,"Rematch clears resize banner and starts with a fresh baseline")
    screen._show_modal("audio")
    resize_to(Vector2i(1320,900))
    check(screen.local_match.state.status == "finished" and screen.modal_kind.is_empty(),"Resize ends active local play even behind a menu")
    var local_state: Dictionary = screen.state.duplicate(true)
    resize_to(Vector2i(1300,900))
    check(screen.state == local_state,"Repeated resize cannot finalize the local match again")
    screen._leave()
    await settle()
    check(not game._resize_ended and game.routes.route == "title","Leaving the duel clears the banner")
    game.queue_free()
    game = null
    screen = null
    toy = null
    merge_peer = null
    bomb = null
    for frame in range(12): await process_frame
    await create_timer(0.25).timeout
    OS.delay_msec(250)
    print("RESIZE_TERMINATION assertions=%d failures=%d" % [assertions,failures.size()])
    if failures.is_empty(): print("PASS: actual-size solo/paused/local termination, exact banner, input/score freeze and replay reset")
    quit(0 if failures.is_empty() else 1)
