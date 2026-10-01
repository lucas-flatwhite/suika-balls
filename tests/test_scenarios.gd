extends SceneTree
var game: Node
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.settings.path = "user://scenario-settings.json"
    game.leaderboard.path = "user://scenario-board.json"
    game.tweaks.reset_all()
    game.audio.set_muted(true)
    for index in range(game.Stages.STAGES.size()):
        game.start_stage(index)
        var frames := 0
        var next_drop_frame := 30
        while game.routes.route == "gameplay" and game.session.goals_reached == 0 and frames < 12000:
            if frames >= next_drop_frame and game.claw_state == game.ClawState.HOLDING and game.session.can_drop():
                var target_x := 720.0
                var top := 10000.0
                for toy in get_nodes_in_group("plushies"):
                    if toy.tier == game.held_tier and toy.position.y < top and not toy.merge_locked:
                        top = toy.position.y
                        target_x = toy.position.x
                game.aim_x = target_x
                game._clamp_aim()
                game.request_drop()
                next_drop_frame = frames + 100
            frames += 1
            await physics_frame
        print("SCENARIO stage=",index," outcome=",game.session.outcome," reason=",game.session.reason," drops=",game.drop_count," score=",game.score," seconds=",game.session.elapsed)
        if game.session.goals_reached != 1 or game.session.outcome != "" or game.routes.route != "gameplay": failures.append("Goal did not advance during ordinary physics play "+str(index))
        if not is_equal_approx(game.session.remaining_time(),float(game.session.stage.time_limit)+60.0-game.session.elapsed): failures.append("Physical goal did not extend remaining time by one minute")
        var run_id: String = game.session.run_id
        var drop_count: int = game.drop_count
        var elapsed: float = game.session.elapsed
        for frame in range(80): await physics_frame
        game.request_drop()
        for frame in range(20): await physics_frame
        if game.drop_count <= drop_count or game.session.elapsed <= elapsed or game.session.run_id != run_id: failures.append("Play did not continue in the same physical run")
    game.start_stage(0)
    # Ordinary no-input play reaches the real timer failure, not a forced result.
    for frame in range(11000):
        if game.routes.route == "debrief": break
        await physics_frame
    print("SCENARIO no-input outcome=",game.session.outcome," reason=",game.session.reason)
    if game.session.outcome != "defeat" or game.session.reason != "timeout": failures.append("Idle timeout did not finish")
    game.queue_free()
    for frame in range(8): await process_frame
    for failure in failures: push_error(failure)
    if failures.is_empty(): print("PASS: actual-physics silent goal advancement and continued play and no-input defeat.")
    OS.delay_msec(250)
    quit(0 if failures.is_empty() else 1)
