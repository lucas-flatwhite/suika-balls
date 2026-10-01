extends SceneTree

var failures: Array[String] = []
const SAVE := "user://mushies_save.cfg"
var saved_bytes := PackedByteArray()
var had_save := false

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool,message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)

func run() -> void:
    had_save = FileAccess.file_exists(SAVE)
    if had_save: saved_bytes = FileAccess.get_file_as_bytes(SAVE)
    var packed := load("res://scenes/main.tscn") as PackedScene
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await physics_frame
    check(game.routes.route == "title" and not is_instance_valid(game.held_toy),"Boot must show title without active simulation")
    game.settings.path = "user://physics-test-settings.json"
    game.leaderboard.path = "user://physics-test-leaderboard.json"
    game.tweaks.reset_all()
    game.start_stage(0)
    check(game.held_toy is PlushieBody,"Claw must hold an actual PlushieBody")
    check(game.held_toy.freeze and game.held_toy.collision_layer == 0,"Held toy must be frozen and noncolliding")
    check(PlushieBody.NAMES.size()==11,"There must be eleven plushie tiers")
    var complex_count := 0
    var previous_spans := [88.0,102.0,118.0,134.0,150.0,168.0,188.0,210.0,236.0,270.0,306.0]
    for tier in range(11):
        var sample := PlushieBody.new()
        sample.configure(tier,null)
        check(is_equal_approx(maxf(sample.render_size.x,sample.render_size.y),float(previous_spans[tier])*1.2),"Every plushie must render at exactly 120% of its previous size")
        var used := sample.texture_asset.get_image().get_used_rect()
        var expected_bottom := (float(used.end.y) / sample.texture_asset.get_height() - 0.5) * sample.render_size.y
        var collider_bottom := -INF
        for point in sample.outline: collider_bottom = maxf(collider_bottom,point.y)
        check(absf(collider_bottom-expected_bottom) <= 1.0,"Collision silhouette must meet visible alpha rather than inset metadata")
        check(sample.piece_count > 0,"Every toy must have valid convex collision pieces")
        check(sample.outline.size()>=8,"Every toy must have a detailed silhouette")
        if sample.piece_count > 1: complex_count += 1
        var areas := 0.0
        for child in sample.get_children():
            check(child is CollisionShape2D and child.shape is ConvexPolygonShape2D,"All plushie colliders must use convex geometry")
        sample.impact(0.7)
        sample._process(0.016)
        check(not sample.visual_scale.is_equal_approx(Vector2.ONE),"Impacts must deform the visual layer")
        check(sample.scale.is_equal_approx(Vector2.ONE),"Impact must not scale the physics body")
        var full_scale := Vector2(1.0+sample.squish,1.0/(1.0+sample.squish))
        check((sample.visual_scale-Vector2.ONE).is_equal_approx((full_scale-Vector2.ONE)*0.5),"Impact deformation must be exactly half the previous amplitude on both axes")
        check(is_equal_approx(sample.physics_material_override.bounce,0.46),"Squish reduction must not change bounce")
        for frame in range(240): sample._process(0.016)
        check(absf(sample.squish)<0.002,"Impact squash must settle back to rest")
        sample.held = true
        sample._process(0.016)
        full_scale = Vector2(1.0+sample.squish,1.0/(1.0+sample.squish))
        check((sample.visual_scale-Vector2.ONE).is_equal_approx((full_scale-Vector2.ONE)*0.5),"Held compression must also be halved")
        sample.free()
    check(complex_count>=8,"Most toys must decompose into multiple convex shapes")
    print("Validated eleven silhouette colliders; complex bodies: ",complex_count)

    var held_id: int = game.held_toy.get_instance_id()
    game.request_drop()
    check(game.claw_state == game.ClawState.OPENING,"Click must start claw opening")
    game.request_drop()
    game._advance_claw(0.19)
    check(game.drop_count == 1,"Release phase must emit exactly one toy")
    var released = instance_from_id(held_id)
    check(is_instance_valid(released) and not released.freeze and released.is_in_group("plushies"),"Claw must release the same held physical instance")
    game.request_drop()
    check(game.drop_count == 1,"Input during reload cannot spawn duplicate toys")
    game._advance_claw(0.56)
    check(game.claw_state==game.ClawState.HOLDING and is_instance_valid(game.held_toy),"Reload must grip the next plushie")
    check(game.held_toy.get_instance_id()!=held_id,"Reload must create a new held instance")
    game.restart_game()
    await process_frame

    var a: PlushieBody = game._spawn(0,Vector2(620,590))
    var b: PlushieBody = game._spawn(0,Vector2(730,590))
    a.freeze = true
    b.freeze = true
    game.request_merge(a,b)
    game.request_merge(a,b)
    await process_frame
    await physics_frame
    check(game.merge_count==1 and game.score==20,"Matching pair must merge once and award points")
    check(game.discovered[1],"Merged collectible must be discovered")
    var c: PlushieBody = game._spawn(2,Vector2(560,600))
    var d: PlushieBody = game._spawn(3,Vector2(850,600))
    game.request_merge(c,d)
    check(not c.merge_locked and not d.merge_locked,"Different tiers must not merge")
    var dragon1: PlushieBody = game._spawn(10,Vector2(590,580))
    var dragon2: PlushieBody = game._spawn(10,Vector2(850,580))
    game.request_merge(dragon1,dragon2)
    check(not dragon1.merge_locked and not dragon2.merge_locked,"Final dragons must not merge")
    game.restart_game()
    await process_frame
    game.request_drop()
    game.toggle_pause()
    var timer_before: float = game.claw_timer
    game._process(0.4)
    check(is_equal_approx(game.claw_timer,timer_before),"Pause must freeze the release sequence")
    game.toggle_pause()
    game.toggle_help()
    check(not game.show_help and not game.is_frozen(),"Title-only help cannot freeze gameplay")
    game.toggle_help()
    game.restart_game()
    await process_frame

    var dangerous: PlushieBody = game._spawn(0,Vector2(690,345))
    dangerous.freeze=true
    dangerous.age=2
    game._physics_process(1.0)
    check(game.overflow_time>=0.99 and not game.is_game_over,"Slow toy above line must accumulate overflow")
    dangerous.position.y=600
    game._physics_process(0.1)
    check(game.overflow_time==0,"Leaving line must reset exposure")
    dangerous.position.y=345
    game._physics_process(2.9)
    check(game.is_game_over,"Continuous overflow must end game")
    game.restart_game()
    await process_frame
    check(not game.is_game_over and get_nodes_in_group("plushies").is_empty(),"Restart must clear pile and game over")
    var score_before: int = game.best_score
    var old_mute: bool = game.audio_muted
    game.toggle_audio()
    check(game.audio_muted!=old_mute and game.best_score==score_before,"Mute must preserve best score")
    game.toggle_audio()
    check(game.audio._music_player.stream is AudioStreamOggVorbis,"BGM must remain locally available")
    # Native controls consume activation; only cabinet positions can release.
    game.open_modal("pause")
    game._pointer(game.get_viewport().canvas_transform * game.TANK.get_center())
    check(game.is_paused and game.claw_state==game.ClawState.HOLDING,"Modal input must not drop a toy")
    game.close_modal()
    game._pointer(Vector2(-50,-50))
    check(game.claw_state==game.ClawState.HOLDING,"Off-board activation cannot release")
    game._pointer(game.get_viewport().canvas_transform * game.TANK.get_center())
    check(game.claw_state==game.ClawState.OPENING,"Clicking the projected chamber must release plushies")
    game.queue_free()
    for frame in range(6): await process_frame
    await create_timer(0.15).timeout
    if had_save:
        var file=FileAccess.open(SAVE,FileAccess.WRITE)
        file.store_buffer(saved_bytes)
        file.close()
    else:
        DirAccess.remove_absolute(SAVE)
    if failures.is_empty():
        print("PASS: Mushies claw, silhouettes, squish, merge, pause, overflow, audio, and UI controls.")
        quit(0)
    else:
        print("FAIL: ",failures)
        quit(1)
