extends SceneTree
## Real shared-keyboard input drives the shipped multiplayer UI and both physics worlds.
var game: Node
var screen: Control
var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("run")

func check(value: bool,message: String) -> void:
    assertions += 1
    if not value:
        failures.append(message)
        push_error(message)

func frames(count: int) -> void:
    for frame in range(count): await process_frame

func key(code: Key,pressed: bool,echo := false) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = pressed
    event.echo = echo
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func tap(code: Key) -> void:
    key(code,true)
    key(code,false)

func release_keys() -> void:
    for code in [KEY_A,KEY_D,KEY_SPACE,KEY_J,KEY_L,KEY_K,KEY_LEFT,KEY_RIGHT,KEY_S,KEY_ESCAPE]:
        key(code,false)

func labels(node: Node) -> Array[String]:
    var result: Array[String] = []
    for child in node.get_children():
        if child is Label and child.is_visible_in_tree(): result.append(child.text)
        result.append_array(labels(child))
    return result

func layout(view: Vector2i) -> void:
    root.size = view
    game._viewport_changed()
    await frames(5)

func await_playing() -> void:
    for frame in range(240):
        if screen.phase == "playing": break
        await process_frame
    check(screen.phase == "playing","Local countdown reaches play without a server or ready messages")

func assert_previews(a: Node,b: Node) -> void:
    check(screen.controls.has("next_texture") and screen.controls.has("opponent_next_texture"),"Both cabinets expose next-toy previews")
    if not screen.controls.has("next_texture") or not screen.controls.has("opponent_next_texture"): return
    check(screen.controls.next_texture.texture == game.toy_texture(a.next_tier),"Left preview matches Player 1's actual supply")
    check(screen.controls.opponent_next_texture.texture == game.toy_texture(b.next_tier),"Right preview matches Player 2's actual supply")
    check(screen.controls.next.text == game.t("hud.next",{"toy":game.toy_name(a.next_tier)}),"Left preview names Player 1's next toy")
    check(screen.controls.opponent_next.text == game.t("hud.next",{"toy":game.toy_name(b.next_tier)}),"Right preview names Player 2's next toy")

func run() -> void:
    root.size = Vector2i(1440,900)
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.settings.path = "user://local-splitscreen-settings.json"
    game.settings.values.name = "" # Explicit default-name fixture, independent of player preferences.
    game.leaderboard.path = "user://local-splitscreen-board.json"
    game.audio.set_muted(true)
    game.settings.values.muted = true
    game.tweaks.reset_all()
    game.device.force_mobile = 0
    await layout(Vector2i(1440,900))
    game._hud.controls["ui.multiplayer"].pressed.emit()
    await frames(4)
    screen = game._multiplayer_screen
    check(screen.controls.has("mp.local_splitscreen"),"The multiplayer chooser includes Local Splitscreen")
    if not screen.controls.has("mp.local_splitscreen"):
        game.queue_free()
        await frames(4)
        quit(1)
        return
    screen.controls["mp.local_splitscreen"].pressed.emit()
    await frames(4)
    check(screen.entry_mode == "local" and is_instance_valid(screen.local_match),"Local choice creates an in-process match in the existing multiplayer screen")
    check(not screen.has_method("_start_quick") and not screen.has_method("_connect_room"),"Local entry never creates or connects a WebSocket")
    check(not screen.controls.has("endpoint") and not screen.controls.has("room_code"),"Local play needs no server address or room code")
    check(int(screen.state.player_id) == 1 and screen.state.boards.size() == 2,"Local snapshots identify two players with Player 1 on the left")
    var match_node: Node = screen.local_match
    var a: Node = match_node.boards[0]
    var b: Node = match_node.boards[1]
    check(a.get_world_2d() != b.get_world_2d(),"Each local cabinet owns an independent real physics world")
    check(screen.local_board.position.x < screen.opponent_board.position.x,"Player 1's cabinet is left of Player 2's cabinet")
    check(int(screen.local_board.board.player_id) == 1 and int(screen.opponent_board.board.player_id) == 2,"Existing BoardViews render the correct local player snapshots")
    check(labels(screen).has(game.t("mp.player_one")) and labels(screen).has(game.t("mp.player_two")),"Local board headings identify Player 1 and Player 2")
    tap(KEY_SPACE)
    tap(KEY_K)
    await frames(6)
    check(a.drop_count == 0 and b.drop_count == 0,"Countdown blocks both players' release keys")
    await await_playing()
    check(not screen.local_board.input_enabled and not screen.opponent_board.input_enabled,"Both local BoardViews remain keyboard-only")
    assert_previews(a,b)

    # Every pause affordance must leave both shared-device authorities running.
    game.open_modal("pause")
    game.toggle_pause()
    check(game.routes.modal().is_empty() and not paused,"Direct and retired solo Pause callbacks cannot pause local multiplayer")
    for code in [KEY_P,KEY_PAUSE,KEY_ESCAPE]:
        var clock_before: float = screen.state.remaining_seconds
        var tick_before: int = match_node.state.tick
        tap(code)
        await frames(18)
        check(game.routes.modal().is_empty() and not paused,"Keyboard pause input never creates a local Paused route: %s" % code)
        check(float(screen.state.remaining_seconds) < clock_before and int(match_node.state.tick) > tick_before,"Local authority and timer keep advancing after key %s" % code)
        if not screen.modal_kind.is_empty():
            tap(KEY_ESCAPE)
            await frames(3)
    var controller_clock: float = screen.state.remaining_seconds
    for pressed in [true,false]:
        var controller_start := InputEventJoypadButton.new()
        controller_start.button_index = JOY_BUTTON_START
        controller_start.pressed = pressed
        Input.parse_input_event(controller_start)
        Input.flush_buffered_events()
    await frames(18)
    check(game.routes.modal().is_empty() and not paused and float(screen.state.remaining_seconds) < controller_clock,"Controller Start leaves the local multiplayer clock running")
    for pair in [[Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_FOCUS_IN],[Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_WM_WINDOW_FOCUS_IN]]:
        var clock_before: float = screen.state.remaining_seconds
        game._notification(pair[0])
        await frames(18)
        check(game.routes.modal().is_empty() and not paused and float(screen.state.remaining_seconds) < clock_before,"Focus loss keeps local multiplayer timing and physics active")
        check(not a.is_frozen() and not b.is_frozen(),"Focus loss freezes neither local cabinet")
        game._notification(pair[1])

    var left_start: float = a.aim_x
    var right_start: float = b.aim_x
    key(KEY_A,true)
    key(KEY_L,true)
    check(Input.is_physical_key_pressed(KEY_A) and Input.is_physical_key_pressed(KEY_L),"The test exercises simultaneously held physical keys")
    await frames(16)
    key(KEY_A,false)
    key(KEY_L,false)
    await frames(5)
    check(a.aim_x < left_start-40 and b.aim_x > right_start+40,"Held A and L move the two claws in opposite directions simultaneously")
    left_start = a.aim_x
    right_start = b.aim_x
    key(KEY_D,true)
    await frames(10)
    key(KEY_D,false)
    await frames(5)
    check(a.aim_x > left_start+30 and is_equal_approx(b.aim_x,right_start),"D moves only Player 1's claw")
    left_start = a.aim_x
    key(KEY_J,true)
    await frames(10)
    key(KEY_J,false)
    await frames(5)
    check(is_equal_approx(a.aim_x,left_start) and b.aim_x < right_start-30,"J moves only Player 2's claw")
    left_start = a.aim_x
    right_start = b.aim_x
    key(KEY_LEFT,true)
    await frames(8)
    key(KEY_LEFT,false)
    check(is_equal_approx(a.aim_x,left_start) and is_equal_approx(b.aim_x,right_start),"Unbound left-arrow aiming cannot operate either local player")
    key(KEY_RIGHT,true)
    tap(KEY_S)
    await frames(12)
    release_keys()
    check(is_equal_approx(a.aim_x,left_start) and is_equal_approx(b.aim_x,right_start) and a.drop_count == 0 and b.drop_count == 0,"Unbound S and arrow controls do not operate either local player")

    var promised_left: int = a.next_tier
    key(KEY_SPACE,true)
    await frames(55)
    check(a.drop_count == 1 and b.drop_count == 0,"Space releases exactly one Player 1 toy without affecting Player 2")
    check(a.held_tier == promised_left,"Player 1 receives its promised next toy after release")
    key(KEY_SPACE,true,true)
    await frames(55)
    key(KEY_SPACE,false)
    check(a.drop_count == 1 and b.drop_count == 0,"A held Space key and key-repeat echo never auto-drop a second toy")
    var promised_right: int = b.next_tier
    tap(KEY_K)
    await frames(55)
    check(a.drop_count == 1 and b.drop_count == 1,"K releases exactly one Player 2 toy without affecting Player 1")
    check(b.held_tier == promised_right,"Player 2 receives its promised next toy after release")
    key(KEY_K,true,true)
    key(KEY_K,false)
    await frames(55)
    check(b.drop_count == 1,"Player 2 also rejects key-repeat echo")
    tap(KEY_SPACE)
    tap(KEY_K)
    await frames(55)
    check(a.drop_count == 2 and b.drop_count == 2,"S and K in one input frame independently release both toys")
    assert_previews(a,b)
    check(not FileAccess.file_exists("res://scripts/multiplayer/client.gd"),"Local input creates no network connection or queued commands")

    # Input gating applies equally to both players while overlays are visible.
    for modal in ["audio","leave"]:
        var clock_before: float = screen.state.remaining_seconds
        screen.modal_kind = modal
        screen._build_overlay()
        await frames(3)
        left_start = a.aim_x
        right_start = b.aim_x
        key(KEY_A,true)
        key(KEY_L,true)
        tap(KEY_SPACE)
        tap(KEY_K)
        await frames(18)
        release_keys()
        check(is_equal_approx(a.aim_x,left_start) and is_equal_approx(b.aim_x,right_start) and a.drop_count == 2 and b.drop_count == 2,"%s overlay blocks both players' movement and release" % modal)
        check(float(screen.state.remaining_seconds) < clock_before and not a.is_frozen() and not b.is_frozen(),"%s overlay keeps both local cabinets and the match timer running" % modal)
        tap(KEY_ESCAPE)
        await frames(3)
        check(screen.modal_kind.is_empty(),"Escape dismisses the %s overlay while preserving local play" % modal)
    await layout(Vector2i(700,1000))
    check(is_instance_valid(screen.orientation_cover) and screen.orientation_cover.visible,"Portrait preserves the local match behind the landscape cover")
    left_start = a.aim_x
    right_start = b.aim_x
    key(KEY_D,true)
    key(KEY_J,true)
    tap(KEY_SPACE)
    tap(KEY_K)
    await frames(18)
    release_keys()
    check(is_equal_approx(a.aim_x,left_start) and is_equal_approx(b.aim_x,right_start) and a.drop_count == 2 and b.drop_count == 2,"Portrait cover blocks input to both local cabinets")
    await layout(Vector2i(1440,900))
    check(screen.local_match == match_node and not screen._can_play() and screen.state.result_reason == "resize","Returning to landscape keeps the resized local round ended")
    screen._rematch()
    await await_playing()
    a = screen.local_match.boards[0]
    b = screen.local_match.boards[1]
    # Preserve the following overflow fixture's two prior drops after the fresh round.
    for drop in range(2):
        tap(KEY_SPACE); tap(KEY_K)
        await frames(55)
    check(not screen.local_board.input_enabled and not screen.opponent_board.input_enabled,"Keyboard-only control survives layout rebuilding")
    assert_previews(a,b)

    # A full cabinet stops only its owner; final score decides the round later.
    a.session.score.total = 10000
    b.session.score.total = 10
    a.session.finish("defeat","overflow")
    a._finish_run()
    await frames(8)
    check(screen.phase == "playing" and int(screen.state.winner_id) == 0 and screen.state.result_reason.is_empty(),"Player 1 overflow keeps the shared match running without declaring a winner")
    check(a.is_frozen() and not b.is_frozen(),"Player 1 overflow freezes only the left physics world")
    check(not screen._can_control(true) and screen._can_control(false),"Control ownership follows each player's terminal outcome")
    check(screen.controls.local_status.is_visible_in_tree() and screen.controls.local_status.text == game.t("mp.board_finished"),"The left cabinet identifies Player 1 as finished")
    check(not screen.controls.opponent_status.is_visible_in_tree() and screen.modal_kind.is_empty() and not is_instance_valid(screen.overlay),"The surviving right cabinet remains clear of a finished label and blocking overlay")
    check(screen.controls.controls.text == game.t("mp.board_waiting") and screen.controls.opponent_controls.text == game.t("mp.local_controls_two"),"Finished Player 1 waits for final scores while Player 2 keeps its keyboard hint")
    left_start = a.aim_x
    right_start = b.aim_x
    var left_ui_aim: float = screen.aim_x
    var remaining: float = screen.state.remaining_seconds
    key(KEY_A,true)
    key(KEY_L,true)
    tap(KEY_SPACE)
    tap(KEY_K)
    await frames(16)
    release_keys()
    await frames(45)
    check(is_equal_approx(a.aim_x,left_start) and is_equal_approx(screen.aim_x,left_ui_aim) and a.drop_count == 2,"Finished Player 1 ignores both A movement and S release in the UI and authority")
    check(b.aim_x > right_start+40 and b.drop_count == 3,"Surviving Player 2 can still move with L and release with K")
    check(screen.phase == "playing" and float(screen.state.remaining_seconds) < remaining,"The common match clock continues after the first defeat")
    assert_previews(a,b)
    b.session.finish("defeat","overflow")
    b._finish_run()
    await frames(8)
    check(screen.phase == "finished" and int(screen.state.winner_id) == 1 and screen.state.result_reason == "overflow","Both finished boards resolve by score, allowing first-defeated Player 1 to win")
    check(labels(screen).has(game.t("mp.player_one_win")),"Results announce the higher-scoring Player 1 as the winner")
    check(a.is_frozen() and b.is_frozen(),"The result freezes both local physics worlds")
    tap(KEY_SPACE)
    tap(KEY_K)
    await frames(12)
    check(a.drop_count == 2 and b.drop_count == 3,"The finished match rejects both release keys")
    check(screen.controls.has("rematch") and not screen.controls.rematch.disabled,"Local results offer an immediately available rematch")
    var epoch: int = screen.state.match_epoch
    var old_a: int = a.get_instance_id()
    var old_b: int = b.get_instance_id()
    screen.controls.rematch.pressed.emit()
    await frames(5)
    a = screen.local_match.boards[0]
    b = screen.local_match.boards[1]
    check(screen.phase == "countdown" and int(screen.state.match_epoch) > epoch,"One rematch click starts a fresh shared countdown")
    check(a.drop_count == 0 and b.drop_count == 0 and a.score == 0 and b.score == 0,"Rematch resets both players' scores, drops and outcomes")
    check(a.session.outcome.is_empty() and b.session.outcome.is_empty(),"Rematch clears both terminal outcomes")
    check(not is_instance_id_valid(old_a) or a.get_instance_id() == old_a,"Rematch does not leak an old Player 1 authority")
    check(not is_instance_id_valid(old_b) or b.get_instance_id() == old_b,"Rematch does not leak an old Player 2 authority")
    await await_playing()
    tap(KEY_SPACE)
    tap(KEY_K)
    await frames(55)
    check(a.drop_count == 1 and b.drop_count == 1,"Both keyboard controls work after rematch")
    check(not screen.controls.local_status.is_visible_in_tree() and not screen.controls.opponent_status.is_visible_in_tree(),"Rematch removes both finished-board labels")
    b.session.finish("defeat","overflow")
    b._finish_run()
    await frames(8)
    check(screen.phase == "playing" and screen._can_control(true) and not screen._can_control(false),"Player 2 can finish first while Player 1 stays playable")
    check(not screen.controls.local_status.is_visible_in_tree() and screen.controls.opponent_status.is_visible_in_tree(),"Only the right cabinet shows Finished when Player 2 stops first")
    check(screen.controls.controls.text == game.t("mp.local_controls_one") and screen.controls.opponent_controls.text == game.t("mp.board_waiting"),"Finished Player 2 waits for final scores while Player 1 keeps its keyboard hint")
    left_start = a.aim_x
    right_start = b.aim_x
    var right_ui_aim: float = screen.opponent_aim_x
    key(KEY_D,true)
    key(KEY_J,true)
    tap(KEY_SPACE)
    tap(KEY_K)
    await frames(16)
    release_keys()
    await frames(45)
    check(a.aim_x > left_start+40 and a.drop_count == 2,"Surviving Player 1 retains D movement and S release")
    check(is_equal_approx(b.aim_x,right_start) and is_equal_approx(screen.opponent_aim_x,right_ui_aim) and b.drop_count == 1,"Finished Player 2 ignores J movement and K release in the UI and authority")
    var match_id: int = screen.local_match.get_instance_id()
    var a_id: int = a.get_instance_id()
    var b_id: int = b.get_instance_id()
    screen._request_leave()
    check(screen.modal_kind == "leave","Leaving a live local match opens the shared leave confirmation")
    screen.controls["mp.leave"].pressed.emit()
    await frames(8)
    check(not game.multiplayer_active() and game._hud.visible and game.routes.route == "title","Confirmed leave restores the usable solo title")
    check(not is_instance_id_valid(match_id) and not is_instance_id_valid(a_id) and not is_instance_id_valid(b_id),"Leaving frees the local match and both authorities")
    check(get_nodes_in_group("plushies").is_empty(),"Leaving cleans every local toy and held payload")

    game.open_multiplayer()
    await frames(4)
    screen = game._multiplayer_screen
    check(screen.entry_mode == "choice" and screen.controls.has("mp.local_splitscreen"),"Reentry restores the local multiplayer configuration")
    screen.controls["mp.local_splitscreen"].pressed.emit()
    await frames(5)
    check(screen.local_match.boards.size() == 2 and not screen.has_method("_connect_room"),"Repeated local entry creates exactly two authorities without a socket")
    screen._leave()
    await frames(8)
    check(get_nodes_in_group("plushies").is_empty(),"Leaving during the next countdown also cleans both boards")
    check(game.start_stage(0),"Single-player can start after repeated local sessions")
    tap(KEY_P)
    await frames(3)
    check(game.routes.modal() == "pause","Real solo pause input is restored after local play")
    game.close_modal()
    game.request_drop()
    game._advance_claw(0.2)
    check(game.drop_count == 1 and game.routes.route == "gameplay","Single-player claw and input ownership recover after local play")
    release_keys()
    game.return_title()
    game.queue_free()
    await frames(8)
    await create_timer(0.25).timeout
    OS.delay_msec(250)
    print("Local splitscreen assertions: ",assertions)
    if failures.is_empty(): print("PASS: shared keyboard, isolated physics, dual previews, input gates, results, rematch and solo recovery.")
    quit(0 if failures.is_empty() else 1)
