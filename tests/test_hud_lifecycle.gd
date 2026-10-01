extends SceneTree
var failures: Array[String] = []
var assertions := 0
var game: Node

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
    assertions += 1
    if not value:
        failures.append(message)
        push_error(message)

func settle() -> void:
    for frame in range(4): await process_frame

func check_view() -> void:
    var hud = game._hud
    check(hud.current_route == game.routes.route,"HUD finishes on the latest requested route")
    check(is_instance_valid(hud.base) and hud.base.is_inside_tree(),"Active base remains attached")
    for key in hud.metrics:
        var control = hud.metrics[key]
        check(is_instance_valid(control) and not control.is_queued_for_deletion() and control.is_inside_tree(),"Live metric after rebuild: "+key)
    check(hud.find_child("ui_tweaks",true,false) == null,"Native tuning launcher is absent")

func run() -> void:
    root.size = Vector2i(1440,900)
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.settings.path = "user://hud-lifecycle-settings.json"
    game.leaderboard.path = "user://hud-lifecycle-board.json"
    game.tweaks.reset_all()
    game.audio.set_muted(true)
    var hud = game._hud
    # Re-enter while the active HUD subtree is being attached.
    var trigger := {"armed":true}
    var enter := func(_node: Node):
        if not trigger.armed: return
        trigger.armed = false
        hud.rebuild()
    hud.child_entered_tree.connect(enter)
    hud.rebuild()
    hud.child_entered_tree.disconnect(enter)
    await settle()
    check(not trigger.armed,"Reentrant construction regression was exercised")
    check_view()
    # A control deleted externally must be replaced, never written through a stale reference.
    game.start_stage(0)
    hud.metrics.score.free()
    hud._process(0)
    await settle()
    check(is_instance_valid(hud.metrics.get("score")),"Freed gameplay score is rebuilt safely")
    check_view()
    game.start_stage(0)
    var redirect := {"armed":true}
    var change_route := func(node: Node):
        if redirect.armed and node == hud.base:
            redirect.armed = false
            game.return_title()
            hud.rebuild()
    hud.child_entered_tree.connect(change_route)
    hud.rebuild()
    hud.child_entered_tree.disconnect(change_route)
    await settle()
    check(not redirect.armed and game.routes.route == "title","A route change during construction wins over the interrupted view")
    check_view()
    for iteration in range(3):
        root.size = Vector2i(390,844) if iteration % 2 == 0 else Vector2i(1440,900)
        game._viewport_changed()
        game.start_stage(0)
        var run_id: String = game.session.run_id
        game.open_modal("pause")
        game.open_modal("settings")
        # Retiring a focused child can synchronously request another rebuild or route sync.
        hud.controls["ui.close"].grab_focus()
        hud.controls["ui.close"].tree_exiting.connect(func():
            hud.rebuild()
            hud.sync_routes(),CONNECT_ONE_SHOT)
        game.setting("locale","zh_CN" if iteration % 2 == 0 else "en")
        if game.tweaks.enabled:
            game.tweaks.request("ui.text.scale",1.1 if iteration % 2 == 0 else 1.0)
        hud.rebuild()
        await settle()
        check_view()
        check(game.routes.stack.size() == 2 and hud.modals.size() == 2,"Nested menus survive repeated rebuilds")
        check(game.session.run_id == run_id,"HUD refresh does not restart gameplay")
        game.close_modal(); game.close_modal()
        await settle()
        hud.metrics.score.queue_free()
        await settle()
        check_view()
        check(is_instance_valid(hud.metrics.get("score")),"Freed gameplay metric is replaced")
        game.session.finish("defeat","timeout")
        game._finish_run()
        hud.rebuild()
        await settle()
        check_view()
        game.return_title()
        await settle()
        check_view()
    game.queue_free()
    await settle()
    await create_timer(0.25).timeout
    print("HUD lifecycle assertions: ",assertions)
    if failures.is_empty(): print("PASS: reentrant HUD rebuilds, metric recovery, Addon-only HUD and route lifetimes.")
    quit(0 if failures.is_empty() else 1)
