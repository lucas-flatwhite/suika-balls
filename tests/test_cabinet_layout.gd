extends SceneTree
var game: Node
var assertions := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
    assertions += 1
    if not value: failures.append(message); push_error(message)

func containing_panel(node: Node) -> PanelContainer:
    var parent := node.get_parent()
    while parent != null:
        if parent is PanelContainer: return parent
        parent = parent.get_parent()
    return null

func run() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.settings.path = "user://cabinet-test-settings.json"
    game.leaderboard.path = "user://cabinet-test-board.json"
    game.tweaks.reset_all()
    game.audio.set_muted(true)
    game.start_stage(0)
    var held = game.held_toy
    var outline: PackedVector2Array = held.outline.duplicate()
    var mass: float = held.mass
    for size in [Vector2i(1882,964),Vector2i(2834,1980),Vector2i(1440,900),Vector2i(960,640),Vector2i(390,844),Vector2i(390,1200)]:
        game.return_title()
        root.size = size
        game._viewport_changed()
        game.start_stage(0)
        held = game.held_toy
        game._hud.rebuild()
        for frame in range(4): await process_frame
        var projection: Transform2D = root.canvas_transform
        var cabinet: Rect2 = projection * game.cabinet_bounds()
        check(is_equal_approx(projection.x.length(),projection.y.length()),"Cabinet projection never stretches plushie proportions")
        if game._hud.mobile:
            check(absf(cabinet.position.y-game._hud.mobile_header.end.y) < 0.01 and absf(cabinet.end.y-game._hud.mobile_footer.position.y) < 0.01,"Portrait cabinet fits between header and footer")
        elif not game._hud.compact:
            check(absf(cabinet.position.y) < 0.01 and absf(cabinet.end.y-size.y) < 0.01,"Desktop and mobile cabinet fill the screen from top to bottom")
        else:
            var top := containing_panel(game._hud.metrics.goal)
            var bottom := containing_panel(game._hud.controls["ui.drop"])
            check(absf(cabinet.position.y-top.get_global_rect().end.y) < 0.01,"Portrait cabinet meets the HUD without an empty gap")
            check(absf(cabinet.end.y-bottom.get_global_rect().position.y) < 0.01,"Portrait cabinet meets touch controls without an empty gap")
        check(cabinet.position.x >= 0 and cabinet.end.x <= size.x+0.01,"Full-height cabinet remains within screen width")
        check(game.tank_rect.end.y-game.danger_y() >= 498.0-0.01,"Pile capacity grows by at least 80 logical pixels")
        check(held.outline == outline and held.mass == mass and held.scale == Vector2.ONE,"Resizing preserves plushie collision geometry and mass")
        check(game.routes.route == "gameplay" and game.session.outcome.is_empty(),"A new run uses the selected cabinet size")
        var floor_body: StaticBody2D = get_first_node_in_group("cabinet_floor")
        var floor_shape = floor_body.get_child(0).shape
        check(is_equal_approx(floor_body.position.y-floor_shape.size.y*0.5,game.tank_rect.end.y),"Collision floor matches the enlarged visible playfield")
        check(game.feedback.bounds == game.tank_rect,"Effects use the same enlarged playfield bounds")
    game.return_title()
    root.size = Vector2i(1882,964)
    game._viewport_changed()
    game.start_stage(0)
    game._hud.rebuild()
    while not game.routes.stack.is_empty(): game.close_modal()
    var toy = game._spawn(0,Vector2(720,game.TANK.end.y+20))
    for frame in range(180): await physics_frame
    check(toy.world_bounds().end.y > game.TANK.end.y+60,"A physical toy can occupy the newly added room below the old floor")
    check(absf(toy.world_bounds().end.y-game.tank_rect.end.y) < 8,"The toy settles on the new floor instead of falling through it")
    var clearance: float = game.tank_rect.end.y-toy.position.y
    var toy_id: int = toy.get_instance_id()
    game.open_modal("pause")
    root.size = Vector2i(390,1200)
    game._hud.rebuild()
    check(toy.get_instance_id() == toy_id and is_equal_approx(game.tank_rect.end.y-toy.position.y,clearance),"Existing pile preserves floor clearance as the cabinet becomes taller")
    root.size = Vector2i(1882,964)
    game._hud.rebuild()
    check(is_equal_approx(game.tank_rect.end.y-toy.position.y,clearance),"Returning to landscape preserves the same pile placement")
    check(game.session.reason == "resize" and game.is_frozen(),"Paused cabinet resize ends play while preserving its final visual geometry")
    game.start_stage(0)
    var before: int = game.drop_count
    game._pointer(root.canvas_transform*Vector2(900,game.TANK.end.y+40))
    game._advance_claw(0.2)
    check(game.drop_count == before+1,"The newly exposed part of the playfield accepts drop input")
    game.queue_free()
    for frame in range(8): await process_frame
    await create_timer(0.25).timeout
    OS.delay_msec(250)
    print("Cabinet layout assertions: ",assertions)
    if failures.is_empty(): print("PASS: full-height cabinet, real added capacity, physical floor, input and resize termination.")
    quit(0 if failures.is_empty() else 1)
