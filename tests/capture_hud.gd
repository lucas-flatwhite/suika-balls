extends SceneTree
## Render actual gameplay and reject HUD content hidden behind panel scrolling.
var game: Node
var canvas: SubViewport
var destination := ""
var failures: Array[String] = []
var captures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool,message: String) -> void:
    if not value:
        failures.append(message)
        push_error(message)

func verify_control(control: Control,label: String) -> void:
    var rect := control.get_global_rect()
    check(Rect2(Vector2.ZERO,canvas.size).grow(1).encloses(rect),label+" fits viewport")
    var ancestor := control.get_parent()
    while ancestor != game._hud and ancestor != null:
        if ancestor is ScrollContainer:
            check(ancestor.get_global_rect().grow(1).encloses(rect),label+" is fully visible in panel")
            var scrollbar: VScrollBar = ancestor.get_v_scroll_bar()
            check(scrollbar.max_value <= scrollbar.page+1,label+" needs no vertical scrolling")
        ancestor = ancestor.get_parent()

func verify_pause_content(node: Node,label: String) -> void:
    for child in node.get_children():
        if child is Label or child is Button: verify_control(child,label+" "+child.text)
        verify_pause_content(child,label)

func shot(label: String,verify := true) -> void:
    for frame in range(12):
        # Native focus changes may open Pause while rendering an offscreen viewport.
        if verify and not game.routes.stack.is_empty():
            while not game.routes.stack.is_empty(): game.close_modal()
            game._hud.rebuild()
        await process_frame
    if verify and not game._hud.mobile:
        for key in ["score","time","stage","goal","drops","next","goal_texture","next_texture"]:
            check(game._hud.metrics.has(key),label+" includes "+key)
            if game._hud.metrics.has(key): verify_control(game._hud.metrics[key],label+" "+key)
        for key in ["ui.drop","ui.pause","ui.collection"]:
            verify_control(game._hud.controls[key],label+" "+key)
        if game._hud.launcher != null: verify_control(game._hud.launcher,label+" owner launcher")
    if not verify and not game._hud.mobile and game.routes.modal() == "pause":
        var pause: Control = game._hud.modals.back()
        check(pause.find_children("*","Button",true,false).size() == 5,label+" includes all five pause actions")
        verify_pause_content(pause,label)
        check(game.is_frozen(),label+" keeps the game paused")
    RenderingServer.force_draw(false)
    check(canvas.get_texture().get_image().save_png(destination+"/"+label+".png") == OK,"Saved "+label)
    captures += 1
    print("CAPTURE ",label)

func run() -> void:
    destination = OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(destination)
    canvas = SubViewport.new()
    canvas.size = Vector2i(1024,768)
    canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(canvas)
    game = load("res://scenes/main.tscn").instantiate()
    canvas.add_child(game)
    await process_frame
    game.settings.path = "user://hud-capture-settings.json"
    game.leaderboard.path = "user://hud-capture-board.json"
    game.tweaks.reset_all()
    game.audio.set_muted(true)
    game.device.force_mobile = 0
    for locale in ["en","zh_CN"]:
        game.locale.locale = locale
        game.start_stage(0)
        var run_id: String = game.session.run_id
        for size in [Vector2i(800,600),Vector2i(1024,768),Vector2i(1280,960),Vector2i(1600,1200),Vector2i(1440,900),Vector2i(1882,964),Vector2i(2560,1440),Vector2i(390,844)]:
            canvas.size = size
            game._viewport_changed()
            check(game.session.run_id == run_id,"Resize preserves active run")
            await shot("gameplay-%s-%dx%d" % [locale,size.x,size.y])
        for size in [Vector2i(800,600),Vector2i(1024,768)]:
            canvas.size = size
            game.session.score.total = 10000000
            game.session.goals_reached = 123
            game.session.goal_tier = 10
            game.session.goal_quantity = 125
            game.session.drops = 999
            game.next_tier = 8
            game._viewport_changed()
            await shot("large-values-%s-%dx%d" % [locale,size.x,size.y])
            if game.tweaks.enabled:
                game.tweaks.request("ui.text.scale",1.2)
                await shot("large-text-%s-%dx%d" % [locale,size.x,size.y])
                game.tweaks.request("ui.text.scale",1.0)
        canvas.size = Vector2i(1024,768)
        game.start_stage(0)
        for size in [Vector2i(800,600),Vector2i(1024,768),Vector2i(1280,960),Vector2i(1600,1200),Vector2i(1440,900),Vector2i(390,844)]:
            canvas.size = size
            game._viewport_changed()
            while not game.routes.stack.is_empty(): game.close_modal()
            game.open_modal("pause")
            await shot("pause-%s-%dx%d" % [locale,size.x,size.y],false)
            if game.tweaks.enabled and not game._hud.mobile:
                game.tweaks.request("ui.text.scale",1.2)
                await shot("pause-large-text-%s-%dx%d" % [locale,size.x,size.y],false)
                game.tweaks.request("ui.text.scale",1.0)
                for frame in range(4): await process_frame
            game.close_modal()
    game.queue_free()
    for frame in range(8): await process_frame
    canvas.queue_free()
    for frame in range(4): await process_frame
    OS.delay_msec(250)
    print("HUD captures: ",captures,"; failures: ",failures.size())
    quit(0 if failures.is_empty() else 1)
