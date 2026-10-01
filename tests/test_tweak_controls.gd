extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
    if not ok: failures.append(message); push_error(message)
func run() -> void:
    var game: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.start_stage(0)
    var active: Variant = game.tweaks.value("gameplay.time_limit")
    check(game.tweaks.apply_preview_patch({"gameplay.time_limit": active + 30}), "Valid Apply accepted")
    check(game.tweaks.value("gameplay.time_limit") == active, "Next-run value stays pending")
    check(not game.is_frozen(), "Apply does not pause the game")
    game.tweaks.begin_run()
    check(game.tweaks.value("gameplay.time_limit") == active + 30, "Next run consumes the pending value")
    check(game.tweaks.tainted, "Consumed gameplay override taints rank eligibility")
    game.audio.set_muted(true)
    game.queue_free()
    for node: Node in root.get_children(): node.queue_free()
    await process_frame
    await create_timer(0.25).timeout
    print("TUNING_CONTROLS: ", "PASS" if failures.is_empty() else str(failures))
    quit(0 if failures.is_empty() else 1)
