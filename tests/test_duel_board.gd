extends SceneTree
## Two real physics worlds exercise server isolation, progression and lifecycle.
const Board := preload("res://scripts/game/board_simulation.gd")
const Protocol := preload("res://scripts/multiplayer/protocol.gd")
var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("run")

func check(value: bool,message: String) -> void:
    assertions += 1
    if not value:
        failures.append(message)
        push_error(message)

func make_board() -> Node2D:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1440,900)
    viewport.world_2d = World2D.new()
    root.add_child(viewport)
    var board := Board.new()
    viewport.add_child(board)
    return board

func run() -> void:
    var a = make_board()
    var b = make_board()
    a.start_duel(14327)
    b.start_duel(14327)
    check(a.get_world_2d() != b.get_world_2d(),"Opponents have independent real physics worlds")
    check(a.held_tier == b.held_tier and a.next_tier == b.next_tier,"Identical seed gives identical starting supply")
    check(not a.tweaks.enabled and a.tweaks.active == b.tweaks.active,"Duel boards use untuned baseline physics")
    check(a.audio.get_child_count() == 0 and b.audio.get_child_count() == 0,"Authority creates no audio players")
    check(a._hud == null and a._ink == null,"Authority creates no HUD")
    check(not a.is_processing_input() and not a.is_processing_unhandled_input(),"Authority accepts no device input")
    a.apply_input(NAN,true)
    check(a.claw_state == a.ClawState.HOLDING and is_finite(a.aim_x),"Non-finite input is rejected")
    a.apply_input(-1000000,false)
    check(a.aim_x > a.tank_rect.position.x,"Aim clamps to the physical cabinet")
    a.apply_input(720,true)
    for frame in range(65): await physics_frame
    check(a.drop_count == 1 and b.drop_count == 0,"Only the commanded player releases a toy")
    check(a.get_board_toys().size() == 1 and b.get_board_toys().is_empty(),"Dropped body belongs only to its board")
    var dropped = a.get_board_toys()[0]
    var before: Vector2 = dropped.position
    for frame in range(30): await physics_frame
    check(dropped.position.distance_to(before) > 1,"Released authoritative toy simulates real falling physics")
    var a_state: Dictionary = a.snapshot()
    check(a_state.toys.size() == 1 and a_state.toys[0].id > 0 and a_state.held.id != a_state.toys[0].id,"Snapshot provides unique stable body identities")
    check(a_state.toys[0].width > 0 and a_state.toys[0].height > 0,"Snapshot keeps original sprite aspect ratio")
    var geometry: Rect2 = a.tank_rect
    root.size = Vector2i(390,844)
    await process_frame
    check(a.tank_rect == geometry and b.tank_rect == geometry,"Viewport resizing never changes duel capacity")
    a.stop()
    await physics_frame
    await process_frame
    var frozen: Vector2 = dropped.position
    a.apply_input(900,true)
    for frame in range(8): await physics_frame
    check(dropped.freeze and dropped.position == frozen and a.drop_count == 1,"Stop freezes physics and rejects inputs")
    a.set_active(true)
    check(not dropped.freeze and a.held_toy.freeze,"Resume releases pile physics but keeps claw payload held")
    a._clear_run()
    b._clear_run()
    a.start_duel(77)
    b.start_duel(77)
    # Cross-world contact callbacks and malicious merge pairs are explicitly rejected.
    var a1 = a._spawn(0,Vector2(600,650))
    var a2 = a._spawn(0,Vector2(800,650))
    var b1 = b._spawn(0,Vector2(600,650))
    a.request_merge(a1,b1)
    check(not a1.merge_locked and not b1.merge_locked,"Cross-board merge pair is rejected")
    a.request_merge(a1,a2)
    await process_frame
    check(a.merge_count == 1 and b.merge_count == 0 and is_instance_valid(b1),"Deferred merge changes only its owning board")
    check(a.score > 0 and b.score == 0,"Opponent score cannot be changed by another board")
    var before_budget: float = a.session.time_budget()
    a.session.merge(3)
    check(a.session.goals_reached > 0 and a.session.time_budget() == before_budget,"Goal reward never extends shared duel timer")
    a.session.tick(500)
    check(a.session.outcome == "","Only the match server resolves duel timeout")
    var b_before: Vector2 = b1.position
    a._resize_tank(a.tank_rect.end.y+30)
    check(b1.position == b_before,"Cabinet resizing cannot move another board's pile")
    a._clear_run()
    check(is_instance_valid(b1) and not b1.is_queued_for_deletion() and b.get_board_toys().size() == 1,"Run cleanup never deletes the opponent pile")
    a.start_duel(88)
    var bomb = a._spawn(a.BombDefinition.TIER,Vector2(600,650))
    bomb.set_physics_process(false)
    var victim = a._spawn(1,Vector2(600,650))
    a.request_bomb_detonation(bomb,[victim,b1])
    await process_frame
    check(not is_instance_valid(bomb) and not is_instance_valid(victim),"Bomb clears its authoritative board contacts")
    check(is_instance_valid(b1) and not b1.destroy_pending,"Bomb ignores opponent even at identical coordinates")
    a.start_duel(99)
    for index in range(a.MAX_TOYS):
        var toy = a._spawn(0,Vector2(700,700))
        if is_instance_valid(toy):
            toy.freeze = true
            toy.position = Vector2(600.0+index*0.123456789,700.0+index*0.234567891)
            toy.rotation = index*0.345678912
            toy.linear_velocity = Vector2(index*0.456789123,index*0.567891234)
    check(a._spawn(0,Vector2(700,700)) == null,"Board enforces its own toy population limit")
    check(b._spawn(1,Vector2(900,700)) != null,"Full opponent board never consumes this board's spawn allowance")
    var dense: Dictionary = a.snapshot()
    var board_bytes := JSON.stringify(dense).to_utf8_buffer().size()
    var duel_state := {"type":"state","state":{"status":"playing",
        "players":[{"id":1,"ready":true,"rematch":false},{"id":2,"ready":true,"rematch":false}],
        "boards":[dense,dense.duplicate(true)],"countdown":0.0,"remaining_seconds":179.5,
        "winner_id":0,"result_reason":"","match_epoch":1,"tick":900}}
    for index in range(2):
        duel_state.state.boards[index].player_id = index+1
        duel_state.state.boards[index].ack_seq = 900
    var duel_bytes := JSON.stringify(duel_state).to_utf8_buffer().size()
    check(duel_bytes < 262144,"Two full boards keep the presentation snapshot within 256 KiB")
    print("DENSE_SNAPSHOT board_bytes=%d duel_bytes=%d" % [board_bytes,duel_bytes])
    a.stop()
    b.stop()
    check(b1.freeze,"Stopping a board freezes all its own bodies")
    a.start_duel(14327)
    check(a.drop_count == 0 and a.score == 0 and a.snapshot().toys.is_empty(),"Rematch starts a fresh authoritative board")
    check(not b.is_queued_for_deletion() and b.get_board_toys().size() == 2,"Rematch leaves the other board untouched")
    a.get_parent().queue_free()
    b.get_parent().queue_free()
    for frame in range(4): await process_frame
    check(get_nodes_in_group("plushies").is_empty(),"Room deletion releases all authoritative bodies")
    print("Duel board assertions: ",assertions)
    if failures.is_empty(): print("PASS: authoritative physics, board isolation, input, bombs, timer and rematch.")
    quit(0 if failures.is_empty() else 1)
