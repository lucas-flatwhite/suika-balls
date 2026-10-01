extends SceneTree
var game: Node
var canvas: SubViewport
var destination := ""
func _initialize() -> void: call_deferred("run")
func shot(label: String) -> void:
    if label.begins_with("gameplay") or label.begins_with("goal-advanced"):
        while not game.routes.stack.is_empty(): game.close_modal()
    for frame in range(8): await process_frame
    RenderingServer.force_draw(false)
    canvas.get_texture().get_image().save_png(destination+"/release-"+label+".png")
    print("CAPTURE release-",label)
func run() -> void:
    destination = OS.get_cmdline_user_args()[0]
    canvas = SubViewport.new()
    canvas.size = Vector2i(1440,900)
    canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(canvas)
    game = load("res://scenes/main.tscn").instantiate()
    canvas.add_child(game)
    await process_frame
    game.settings.path = "user://release-capture-settings.json"
    game.leaderboard.path = "user://release-capture-board.json"
    game.audio.set_muted(true)
    for locale in ["en","zh_CN"]:
        game.locale.locale = locale
        for size in [Vector2i(1882,964),Vector2i(1440,900),Vector2i(960,640),Vector2i(390,844)]:
            canvas.size = size
            game.return_title()
            game._hud.rebuild()
            var suffix: String = locale+("-portrait" if size.x < 500 else ("-reference" if size.x == 1882 else ("-minimum" if size.x == 960 else "-landscape")))
            await shot("title-"+suffix)
            game.start_stage(0)
            await shot("gameplay-"+suffix)
            while not game.routes.stack.is_empty(): game.close_modal()
            game.session.elapsed = 170.0
            var first = game._spawn(2,Vector2(610,650))
            var second = game._spawn(2,Vector2(760,650))
            game._merge(first,second,game._run_generation)
            if game.session.goals_reached != 1 or game.session.remaining_time() != 70.0:
                push_error("Capture fixture failed to complete a goal and extend time"); quit(1); return
            await shot("goal-advanced-"+suffix)
            game.session.tick(game.session.remaining_time())
            game._finish_run()
            await shot("defeat-"+suffix)
    game.queue_free()
    for frame in range(8): await process_frame
    canvas.queue_free()
    for frame in range(4): await process_frame
    OS.delay_msec(250)
    quit()
