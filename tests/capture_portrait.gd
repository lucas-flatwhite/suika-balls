extends SceneTree
## Native release-pack evidence for portrait previews and visible-height changes.
var game: Node
var canvas: SubViewport
var destination := ""

func _initialize() -> void: call_deferred("run")

func shot(label: String) -> void:
    for frame in range(6): await process_frame
    RenderingServer.force_draw(false)
    canvas.get_texture().get_image().save_png(destination+"/portrait-"+label+".png")
    print("CAPTURE portrait-",label," board=",game.board_screen_rect," chamber=",canvas.canvas_transform*game.tank_rect)

func run() -> void:
    destination = OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(destination)
    canvas = SubViewport.new()
    canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(canvas)
    game = load("res://scenes/main.tscn").instantiate()
    canvas.add_child(game)
    await process_frame
    game.settings.path = "user://portrait-capture-settings.json"
    game.leaderboard.path = "user://portrait-capture-board.json"
    game.tweaks.reset_all()
    game.audio.set_muted(true)
    for locale in ["en","zh_CN"]:
        game.locale.locale = locale
        for size in [Vector2i(320,568),Vector2i(390,640),Vector2i(390,844),Vector2i(520,858),Vector2i(601,1000),Vector2i(768,1024),Vector2i(1024,1366),Vector2i(1440,900)]:
            canvas.size = size
            game.device.force_mobile = 1 if size.x < 500 else 0
            game.device.safe_insets = Vector4(0,44,0,34) if size.x < 500 else Vector4.ZERO
            game.return_title()
            game._viewport_changed()
            var suffix := "%s-%dx%d" % [locale,size.x,size.y]
            await shot("title-"+suffix)
            game.start_stage(0)
            while not game.routes.stack.is_empty(): game.close_modal()
            for index in range(5):
                game._spawn(index,Vector2(465+index*110,game.tank_rect.end.y-100-index*20))
            for frame in range(120): await physics_frame
            await shot("play-"+suffix)
            game.open_modal("pause")
            await shot("pause-"+suffix)
    game.queue_free()
    for frame in range(8): await process_frame
    canvas.queue_free()
    for frame in range(4): await process_frame
    OS.delay_msec(250)
    quit()
