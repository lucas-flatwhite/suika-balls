extends SceneTree
var game: Node
var canvas: SubViewport
func _initialize() -> void:
    call_deferred("run")
func shot(label: String) -> void:
    if label.begins_with("gameplay"):
        while not game.routes.stack.is_empty(): game.close_modal()
    for frame in range(6): await process_frame
    RenderingServer.force_draw(false)
    canvas.get_texture().get_image().save_png("res://build/captures/"+label+".png")
    print("CAPTURE ",label)
func run() -> void:
    canvas = SubViewport.new()
    canvas.size = Vector2i(1440,900)
    canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(canvas)
    game = load("res://scenes/main.tscn").instantiate()
    canvas.add_child(game)
    await process_frame
    game.settings.path = "user://capture-settings.json"
    game.leaderboard.path = "user://capture-leaderboard.json"
    game.audio.set_muted(true)
    for lang in ["en","zh_CN"]:
        game.locale.locale = lang
        game._hud.rebuild()
        for view in [Vector2i(2834,1980),Vector2i(1440,900),Vector2i(960,640),Vector2i(390,844)]:
            canvas.size = view
            await process_frame
            game.return_title()
            game._hud.rebuild()
            var suffix: String = lang+("-portrait" if view.x < 500 else ("-minimum" if view.x < 1000 else ("-retina" if view.x > 2000 else "-landscape")))
            await shot("title-"+suffix)
            game.open_modal("help")
            await shot("help-"+suffix)
            game.close_modal()
            game.start_stage(1)
            for toy in get_nodes_in_group("plushies"):
                toy.remove_from_group("plushies")
                toy.queue_free()
            await process_frame
            for index in range(4):
                var toy = game._spawn(index,Vector2(465+index*150,690))
                toy.freeze = true
            game.feedback.burst(Vector2(735,650))
            await shot("gameplay-"+suffix)
            game.open_modal("pause")
            await shot("pause-"+suffix)
            game.open_modal("settings")
            await shot("settings-"+suffix)
            game.close_modal()
            game.close_modal()
            if game.tweaks.enabled:
                game.open_modal("tweaks")
                await shot("tweaks-"+suffix)
                game.close_modal()
            game.session.merge(game.session.goal_tier)
            await shot("goal-advanced-"+suffix)
            game.open_modal("leaderboard")
            await shot("leaderboard-"+suffix)
            game.close_modal()
            game.start_stage(0)
            game.session.finish("defeat","overflow")
            game._finish_run()
            await shot("defeat-"+suffix)
    game.queue_free()
    for frame in range(4): await process_frame
    quit()
