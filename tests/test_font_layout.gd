extends SceneTree
## Exercise rendered labels after locale, width and live-counter changes.
var game: Node
var failures: Array[String] = []
var assertions := 0
var capture_dir := ""

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="): capture_dir = argument.trim_prefix("--capture=")
    call_deferred("run")

func check(value: bool,message: String) -> void:
    assertions += 1
    if not value:
        failures.append(message)
        push_error(message)

func run() -> void:
    root.size = Vector2i(320,568)
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.settings.path = "user://font-layout-settings.json"
    game.leaderboard.path = "user://font-layout-board.json"
    game.tweaks.reset_all()
    game.audio.set_muted(true)
    game.device.force_mobile = 1
    for weight in [400,500,700]:
        var face: Font = game.locale.font_for_weight(weight)
        check(face.get_font_name().begins_with("Nunito"),"The requested weight resolves to the Nunito UI face")
        check(face.fallbacks.size() == 1 and face.fallbacks[0].get_font_name().begins_with("Noto Sans SC"),"Every weight falls back to Noto Sans SC for Chinese")
        check(face.fallbacks[0].variation_opentype == face.variation_opentype,"Chinese fallback uses the same weight as the Latin face")
    for locale in ["en","zh_CN"]:
        game.locale.locale = locale
        for size in [Vector2i(320,568),Vector2i(375,667),Vector2i(390,844),Vector2i(768,1024)]:
            root.size = size
            game.device.safe_insets = Vector4(0,44,0,34)
            game.start_stage(0)
            game.session.score.total = 999999999
            game.session.goal_quantity = 125
            game.session.elapsed = 0
            game._viewport_changed()
            for tier in [1,8,10]:
                game.session.goal_tier = tier
                game.next_tier = tier
                for frame in range(5): await process_frame
                for key in ["score","time","goal","next"]:
                    var label: Label = game._hud.metrics[key]
                    var face: Font = label.get_theme_font("font")
                    var font_size: int = label.get_theme_font_size("font_size")
                    var context := "%s %dx%d %s %s" % [locale,size.x,size.y,key,label.text]
                    check(font_size >= 14,"Readable minimum size: "+context)
                    check(label.get_global_rect().end.y <= game.board_screen_rect.position.y,"Readout stays above cabinet: "+context)
                    check(label.get_visible_line_count() == label.get_line_count(),"Every wrapped line remains visible: "+context)
                    if key in ["goal","next"]:
                        check(label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,"Toy names are not ellipsized: "+context)
                        check(label.get_line_count() <= 2,"Full toy name fits its two-line budget: "+context)
                    else:
                        check(face.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= label.size.x+0.1,"Complete counter fits without ellipsis: "+context)
                    var outer := label.get_parent()
                    while outer != null and not outer is PanelContainer: outer = outer.get_parent()
                    check(outer != null and outer.get_global_rect().grow(0.5).encloses(label.get_global_rect()),"Readout is contained by its card: "+context)
                if not capture_dir.is_empty() and tier == 1 and size.x in [320,375]:
                    DirAccess.make_dir_recursive_absolute(capture_dir)
                    RenderingServer.force_draw(false)
                    check(root.get_texture().get_image().save_png(capture_dir+"/font-layout-%s-%d.png" % [locale,size.x]) == OK,"Saved actual font-layout capture")
            # Restore shorter live text without a viewport rebuild; fitting must recover.
            game.session.score.total = 1
            game.session.goal_quantity = 1
            game.session.goal_tier = 0
            for frame in range(4): await process_frame
            var score: Label = game._hud.metrics.score
            check(score.get_theme_font_size("font_size") == int(score.get_meta("ui_max_font_size")),"Short counters regain their intended size")
    game.queue_free()
    for frame in range(5): await process_frame
    await create_timer(0.25).timeout
    OS.delay_msec(250)
    print("Font layout assertions: ",assertions)
    if failures.is_empty(): print("PASS: UI font weights, fallback, live readouts and two-line name wrapping.")
    quit(0 if failures.is_empty() else 1)
