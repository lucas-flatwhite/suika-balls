extends SceneTree
const Migration := preload("res://scripts/core/storage_migration.gd")
var game: Node
var assertions := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
    assertions += 1
    if not value: failures.append(message); push_error(message)
func touch(at: Vector2,pressed: bool,index := 0) -> void:
    var event := InputEventScreenTouch.new()
    event.position = at
    event.pressed = pressed
    event.index = index
    Input.parse_input_event(event)

func run() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.settings.path = "user://mobile-test-settings.json"
    game.leaderboard.path = "user://mobile-test-board.json"
    game.audio.set_muted(true)
    game.tweaks.reset_all()
    game.device.force_mobile = 0
    game.start_stage(0)
    # Portrait layout must work in previews and desktop-UA tablets without detection.
    for size in [Vector2i(520,858),Vector2i(601,1000),Vector2i(768,1024),Vector2i(1024,1366)]:
        game.return_title()
        root.size = size
        game._viewport_changed()
        game.start_stage(0)
        for frame in range(4): await process_frame
        check(game._hud.mobile and not game.device.portrait_blocked,"Undetected portrait viewports use the floating HUD without blocking play")
        check(game.board_screen_rect.position.y == game._hud.mobile_header.end.y and game.board_screen_rect.end.y == game._hud.mobile_footer.position.y,"Cabinet fits between persistent header and footer")
        var projected: Rect2 = root.canvas_transform * game.tank_rect
        check(projected.position.y >= game._hud.mobile_header.end.y and projected.end.y <= game._hud.mobile_footer.position.y,"Chamber stays clear of header and footer")
    game.device.force_mobile = 1
    game.start_stage(0)
    for size in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(768,1024)]:
        game.return_title()
        root.size = size
        game.device.safe_insets = Vector4(0,44,0,34)
        game._viewport_changed()
        game.start_stage(0)
        for frame in range(4): await process_frame
        check(game._hud.mobile and not game.device.portrait_blocked,"Detected mobile portrait selects the touch HUD")
        check(game.board_screen_rect.position.y == game._hud.mobile_header.end.y and game.board_screen_rect.end.y == game._hud.mobile_footer.position.y,"Cabinet fits between persistent header and footer")
        var projection: Transform2D = root.canvas_transform
        check(is_equal_approx(projection.x.length(),projection.y.length()),"Mobile layout preserves physical sprite proportions")
        for key in ["ui.drop","ui.left","ui.right"]:
            check(not game._hud.controls.has(key),"Mobile play uses the cabinet instead of action buttons: "+key)
        var rect: Rect2 = game._hud.controls["ui.pause"].get_global_rect()
        check(rect.size.x >= 44 and rect.size.y >= 44,"Mobile Pause keeps a real touch-sized target")
        check(rect.position.x >= 0 and rect.end.x <= size.x and rect.position.y >= 44 and rect.end.y <= size.y-34,"Mobile Pause respects device safe areas")
        check(is_equal_approx(game._hud.mobile_footer.size.y,34.0+(56.0 if game.tweaks.enabled else 0.0)),"Removing the action row gives its entire footer space back to the cabinet")
        if game.tweaks.enabled:
            check(not game._hud.launcher.get_global_rect().intersects(game.board_screen_rect),"Owner launcher stays clear of direct cabinet touch input")
        check(game.routes.route == "gameplay" and game.session.outcome.is_empty(),"New mobile runs use the selected screen size")

    var owner_enabled: bool = game.tweaks.enabled
    game.tweaks.enabled = false
    game._hud.rebuild()
    for frame in range(4): await process_frame
    check(is_equal_approx(game._hud.mobile_footer.size.y,34.0),"Player-facing mobile footer reserves only the bottom safe area")
    check(is_equal_approx(game.board_screen_rect.end.y,root.size.y-34.0),"Player-facing cabinet reaches the bottom safe-area boundary")
    game.tweaks.enabled = owner_enabled

    for density in [2,3]:
        game.return_title()
        root.size = Vector2i(390,844)*density
        game.DeviceLayout.apply_window_scale(root,Vector2i(390,844))
        game._viewport_changed()
        game.start_stage(0)
        var run_id: String = game.session.run_id
        for frame in range(4): await process_frame
        check(root.get_visible_rect().size.is_equal_approx(Vector2(390,844)),"Retina uses CSS dimensions for layout while retaining device resolution")
        check(game.board_screen_rect.position.y == game._hud.mobile_header.end.y and game.board_screen_rect.end.y == game._hud.mobile_footer.position.y,"Cabinet fits between persistent header and footer")
        var scaled_pause: Rect2 = game._hud.controls["ui.pause"].get_global_rect()
        check(scaled_pause.size.y >= 44 and scaled_pause.end.y <= 810,"Retina preserves the CSS-sized Pause target and safe insets")
        var scaled_tank: Rect2 = root.canvas_transform * game.tank_rect
        var before: int = game.drop_count
        var physical: Vector2 = scaled_tank.get_center()*density
        touch(physical,true)
        await process_frame
        check(game.drop_count == before,"Touching the Retina cabinet aims without releasing early")
        touch(physical,false)
        await process_frame
        game._advance_claw(0.2)
        check(game.drop_count == before+1,"Retina cabinet tap-and-release drops exactly once")
        game._advance_claw(0.6)
        # The Web renderer can retain innerHeight while browser bars shrink CSS height.
        game.open_modal("pause")
        var toy = game._spawn(0,Vector2(500,game.tank_rect.end.y-100))
        var clearance: float = game.tank_rect.end.y-toy.position.y
        game.DeviceLayout.apply_window_scale(root,Vector2i(390,640))
        game._viewport_changed()
        for frame in range(4): await process_frame
        check(game.board_screen_rect.position.y == game._hud.mobile_header.end.y and game.board_screen_rect.end.y == game._hud.mobile_footer.position.y,"Cabinet fits between persistent header and footer")
        check(is_equal_approx(game.tank_rect.end.y-toy.position.y,clearance) and game.session.run_id == run_id,"Browser-bar resizing preserves the pile and current run")
        game.close_modal()
        scaled_tank = root.canvas_transform * game.tank_rect
        check(scaled_tank.end.y <= 640-34,"Browser-bar resizing keeps the playable chamber above the safe-area bottom")
        before = game.drop_count
        physical = scaled_tank.get_center()*Vector2(density,844.0/640.0*density)
        touch(physical,true)
        await process_frame
        touch(physical,false)
        await process_frame
        game._advance_claw(0.2)
        check(game.drop_count == before+1,"Retina touch input stays aligned when CSS height differs from physical canvas height")
        game._advance_claw(0.6)
    game.return_title()
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(390,844)
    game._viewport_changed()
    game.start_stage(0)
    for frame in range(4): await process_frame
    var count: int = game.drop_count
    var drop_at: Vector2 = (root.canvas_transform * game.tank_rect).get_center()
    touch(drop_at,true)
    await process_frame
    check(game.drop_count == count,"A cabinet tap aims until the finger is lifted")
    touch(drop_at,false)
    await process_frame
    game._advance_claw(0.2)
    check(game.drop_count == count+1,"A real touchscreen cabinet tap-and-release drops exactly one toy")
    game._advance_claw(0.6)
    count = game.drop_count
    touch(drop_at,true)
    await process_frame
    game._browser_touch_cancelled([])
    # The Web backend emits an ordinary release after the shell touchcancel.
    touch(drop_at,false)
    await process_frame
    game._advance_claw(0.2)
    check(game.drop_count == count,"Browser cancellation prevents the following ordinary release from dropping in solo play")
    touch(drop_at,true)
    await process_frame
    touch(drop_at,false)
    await process_frame
    game._advance_claw(0.2)
    check(game.drop_count == count+1,"A fresh solo gesture still drops normally after browser cancellation")
    game._advance_claw(0.6)
    count = game.drop_count
    var emulated := InputEventMouseButton.new()
    emulated.device = -1
    emulated.button_index = MOUSE_BUTTON_LEFT
    emulated.position = drop_at
    emulated.pressed = true
    Input.parse_input_event(emulated)
    var emulated_release := emulated.duplicate() as InputEventMouseButton
    emulated_release.pressed = false
    Input.parse_input_event(emulated_release)
    await process_frame
    game._advance_claw(0.2)
    check(game.drop_count == count,"Synthetic mouse events cannot duplicate the touchscreen release")
    count = game.drop_count
    var start := Vector2(150,350)
    touch(start,true)
    await process_frame
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = Vector2(285,400)
    drag.relative = drag.position-start
    Input.parse_input_event(drag)
    await process_frame
    touch(Vector2(120,390),true,1)
    touch(Vector2(120,390),false,1)
    check(game.drop_count == count,"Dragging and a secondary finger do not release early")
    touch(drag.position,false)
    await process_frame
    game._advance_claw(0.2)
    check(game.drop_count == count+1 and game.aim_x > 720,"Drag-and-release aims and releases exactly once")
    game._advance_claw(0.6)

    var bomb = game._spawn(game.BombDefinition.TIER,Vector2(700,650))
    var elapsed: float = game.session.elapsed
    var fuse: float = bomb.fuse_remaining
    root.size = Vector2i(844,390)
    game._viewport_changed()
    game._physics_process(5)
    bomb.advance_fuse(5)
    check(game.device.portrait_blocked and game.is_frozen() and bomb.freeze,"Mobile landscape freezes the physical game")
    check(game.session.elapsed == elapsed and bomb.fuse_remaining == fuse,"Rotation cannot consume run time or bomb fuse time")
    root.size = Vector2i(390,844)
    game._viewport_changed()
    check(game.is_frozen() and bomb.freeze and game.session.reason == "resize","Returning to portrait cannot resume a run ended by resizing")
    game.start_stage(0)
    game.open_modal("pause")
    root.size = Vector2i(844,390)
    game._viewport_changed()
    root.size = Vector2i(390,844)
    game._viewport_changed()
    check(game.is_frozen() and game.routes.route == "debrief" and game.session.reason == "resize","Rotation ends a manually paused run")
    game.close_modal()
    for size in [Vector2i(320,568),Vector2i(390,844),Vector2i(768,1024),Vector2i(1440,900)]:
        root.size = size
        game.device.force_mobile = 0
        game.device.safe_insets = Vector4.ZERO
        game._viewport_changed()
        game.start_stage(0)
        for frame in range(4): await process_frame
        check(not game._hud.controls.has("ui.skip") and not game._hud.controls.has("ui.help"),"Gameplay exposes no instructional overlay or help action")
        var chamber_height: float = game.board_screen_rect.size.y
        game.request_drop()
        game._advance_claw(game.active_open_seconds+0.01)
        var first = game._spawn(0,Vector2(650,650))
        var second = game._spawn(0,Vector2(730,650))
        game._merge(first,second,game._run_generation)
        for frame in range(4): await process_frame
        check(is_equal_approx(game.board_screen_rect.size.y,chamber_height),"Dropping and merging never reserve instruction space")
        if game._hud.mobile:
            check(is_equal_approx(game._hud.mobile_footer.size.y,56.0 if game.tweaks.enabled else 0.0),"Mobile gameplay reserves only its existing owner footer")

    var legacy := "user://mobile-migration-legacy"
    var destination := "user://mobile-migration-new"
    DirAccess.make_dir_recursive_absolute(legacy)
    DirAccess.make_dir_recursive_absolute(destination)
    var name: String = Migration.FILES[0]
    var file := FileAccess.open(legacy.path_join(name),FileAccess.WRITE)
    file.store_string("legacy settings"); file.close()
    DirAccess.remove_absolute(destination.path_join(name))
    Migration.migrate_rename(destination,legacy)
    check(FileAccess.get_file_as_string(destination.path_join(name)) == "legacy settings","Renaming preserves previous native settings")
    file = FileAccess.open(destination.path_join(name),FileAccess.WRITE)
    file.store_string("new settings"); file.close()
    Migration.migrate_rename(destination,legacy)
    check(FileAccess.get_file_as_string(destination.path_join(name)) == "new settings","Migration never overwrites an existing new save")
    game.queue_free()
    for frame in range(8): await process_frame
    OS.delay_msec(250)
    print("Mobile assertions: ",assertions)
    if failures.is_empty(): print("PASS: mobile cabinet touch input, reclaimed layout space, safe areas, orientation termination and save migration.")
    quit(0 if failures.is_empty() else 1)
