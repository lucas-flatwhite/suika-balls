extends SceneTree
const Session := preload("res://scripts/core/session.gd")
const Stages := preload("res://data/stages/registry.gd")
var game: Node
var assertions := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
    assertions += 1
    if not value: failures.append(message); push_error(message)

func run() -> void:
    var supply := Session.new()
    supply.start(Stages.STAGES[0])
    var bombs := 0
    var invalid := 0
    for index in range(100000):
        var tier := supply.next_tier()
        if tier == Session.Bomb.TIER: bombs += 1
        elif tier < 0 or tier > 1: invalid += 1
        supply.record_drop()
    check(Session.Bomb.CHANCE_PERCENT == 1,"Bomb has exactly one winning outcome in a uniform 0..99 draw")
    check(bombs > 800 and bombs < 1200 and invalid == 0,"100,000 draws yield a 1% bomb population with legal ordinary tiers")
    print("BOMB SAMPLE: ",bombs," / 100000")
    supply.start(Stages.STAGES[0])
    for index in range(1000):
        if supply.next_tier(1) == Session.Bomb.TIER: break
        supply.record_drop()
    check(supply.next_tier(1) == Session.Bomb.TIER,"A bomb is announced in the stable Next queue")
    var preview := supply.next_tier(1)
    supply.merge(3)
    check(supply.next_tier(1) == preview,"Goal advancement preserves a queued bomb")
    supply.record_drop()
    check(supply.next_tier() == preview,"The promised bomb is the next held item")

    supply.start(Stages.STAGES[0])
    var current := supply.next_tier()
    check(supply.grant_rescue_bomb(),"First near-defeat rescue is accepted")
    check(supply.next_tier() == current and supply.next_tier(1) == Session.Bomb.TIER,"Rescue replaces Next without replacing the held item")
    supply.merge(3)
    check(not supply.grant_rescue_bomb(),"Goal changes cannot grant another rescue")
    supply.record_drop()
    check(supply.next_tier() == Session.Bomb.TIER,"Rescue preview is delivered on the next load")
    supply.start(Stages.STAGES[0])
    check(not supply.rescue_bomb_granted and supply.grant_rescue_bomb(0),"Restart resets rescue and reload can override the upcoming load")
    check(supply.next_tier() == Session.Bomb.TIER,"Reload rescue is delivered immediately on loading")

    root.size = Vector2i(1440,900)
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.settings.path = "user://bomb-test-settings.json"
    game.leaderboard.path = "user://bomb-test-board.json"
    game.audio.set_muted(true)
    game.tweaks.reset_all()
    game.start_stage(0)
    var near = game._spawn(0,Vector2(700,650))
    near.freeze = true
    near.age = 2
    near.position.y += game.danger_y()+Session.RESCUE_DISTANCE+1-near.world_bounds().position.y
    game._physics_process(0.01)
    check(not game.session.rescue_bomb_granted,"Pile below approach threshold does not trigger rescue")
    near.position.y -= 2
    near.linear_velocity = Vector2(0,100)
    game._physics_process(0.01)
    check(not game.session.rescue_bomb_granted,"Fast falling plushies do not trigger rescue")
    near.linear_velocity = Vector2.ZERO
    near.age = 0
    game._physics_process(0.01)
    check(not game.session.rescue_bomb_granted,"Fresh drops do not trigger rescue")
    near.age = 2
    game.open_modal("pause")
    game._physics_process(0.01)
    check(not game.session.rescue_bomb_granted,"Paused games cannot trigger rescue")
    game.close_modal()
    var held_before = game.held_toy
    game._physics_process(0.01)
    check(game.session.rescue_bomb_granted and game.next_tier == Session.Bomb.TIER,"Settled pile near defeat line queues rescue bomb")
    check(game.held_toy == held_before,"Rescue preserves current claw item")
    check(game.routes.modal().is_empty() and not game._hud.controls.has("ui.skip"),"Rescue delivery leaves gameplay unobstructed")
    game.request_drop()
    game._advance_claw(0.2)
    game._advance_claw(1)
    check(game.held_tier == Session.Bomb.TIER,"Physical claw loads the promised rescue bomb")
    game.request_drop()
    game._advance_claw(0.2)
    game.restart_game()
    check(not game.session.rescue_bomb_granted,"New run restores rescue eligibility")
    game.held_toy.queue_free()
    game.held_toy = null
    game.session._drop_queue.assign([Session.Bomb.TIER,1])
    game.held_tier = Session.Bomb.TIER
    game.next_tier = 1
    game._load_claw()
    var bomb = game.held_toy
    bomb.set_physics_process(false)
    bomb.advance_fuse(10)
    check(not bomb.armed and bomb.fuse_remaining == 5,"Held bombs do not start their fuse")
    check(game.discovered.size() == 11,"The bomb is not a collection or merge tier")
    game.request_drop()
    game._advance_claw(0.2)
    check(bomb.armed and bomb.fuse_remaining == 5 and game.drop_count == 1,"The fuse starts on actual physical release")
    bomb.advance_fuse(0.5)
    game.open_modal("pause")
    bomb.advance_fuse(10)
    check(bomb.fuse_remaining == 4.5,"Pause freezes the bomb countdown")
    game.close_modal()
    bomb.advance_fuse(0.5)
    check(bomb.fuse_remaining == 4,"Resume continues the same countdown")
    game.request_merge(bomb,bomb)
    check(not bomb.merge_locked,"A bomb can never merge")

    # Apply gentle pressure against a stationary plushie to produce real contacts.
    bomb.fuse_remaining = 5
    bomb.position = Vector2(605,650)
    bomb.linear_velocity = Vector2.ZERO
    bomb.angular_velocity = 0
    bomb.lock_rotation = true
    bomb.gravity_scale = 0
    bomb.constant_force = Vector2(350,0)
    var departed = game._spawn(0,Vector2(730,650))
    departed.freeze = true
    for frame in range(200):
        await physics_frame
        if bomb.get_colliding_bodies().has(departed): break
    check(bomb.get_colliding_bodies().has(departed),"Bomb fixture establishes a real plushie contact")
    departed.position = Vector2(950,520)
    var touching = game._spawn(1,Vector2(730,650))
    touching.freeze = true
    # Leave a small physical gap with the alpha-matched silhouettes, still within the blast margin.
    var nearby = game._spawn(2,Vector2(610,500))
    nearby.freeze = true
    var merge_partner = game._spawn(1,Vector2(915,750))
    merge_partner.freeze = true
    for frame in range(200):
        await physics_frame
        if bomb.get_colliding_bodies().has(touching) and not bomb.get_colliding_bodies().has(departed): break
    check(bomb.get_colliding_bodies().has(touching) and not bomb.get_colliding_bodies().has(departed),"Contact snapshot tracks present rather than historical neighbors")
    check(not bomb.get_colliding_bodies().has(nearby),"Nearby blast victim is physically separate")
    var run_id: String = game.session.run_id
    var score: int = game.score
    bomb.advance_fuse(4.999)
    check(not bomb.destroy_pending and not touching.destroy_pending,"Nothing is destroyed before the five-second deadline")
    game.request_merge(touching,merge_partner)
    bomb.advance_fuse(0.001)
    check(bomb.destroy_pending and touching.destroy_pending,"Deadline claims the bomb and current physical contact immediately")
    await process_frame
    await process_frame
    check(not is_instance_valid(bomb) and not is_instance_valid(touching),"Detonation removes the bomb and touching plushie")
    check(not is_instance_valid(nearby) and is_instance_valid(departed),"Nearby plushie is cleared while a distant former contact survives")
    check(is_instance_valid(merge_partner) and not merge_partner.merge_locked,"A blast-cancelled merge releases the surviving partner")
    check(game.score == score and game.merge_count == 0 and game.session.run_id == run_id,"Clearing awards no score or goal and keeps the active run")

    # Exact edge-distance boundary, rotation, overlap and large-toy coverage.
    var probe = game._spawn(Session.Bomb.TIER,Vector2(600,600))
    probe.set_physics_process(false)
    probe.outline = PackedVector2Array([Vector2(-10,-10),Vector2(10,-10),Vector2(10,10),Vector2(-10,10)])
    var target = game._spawn(0,Vector2(630,600))
    target.outline = probe.outline
    check(probe.reaches(target),"A separate plushie 10 px beyond the edge is in range")
    target.position.x = 635
    check(probe.reaches(target),"A plushie exactly 15 px beyond the edge is in range")
    target.position.x = 635.1
    check(not probe.reaches(target),"A plushie beyond 15 px survives")
    target.position = probe.position
    check(probe.reaches(target),"Overlapping silhouettes are in range")
    target.position.x = 637
    target.rotation = PI/4
    check(probe.reaches(target),"Rotated silhouette edges determine reach")
    target.rotation = 0
    target.position.x = 630
    probe.advance_fuse(5)
    check(target.destroy_pending,"Detonation claims a nearby non-contact plushie")
    await process_frame
    await process_frame

    var stale = game._spawn(Session.Bomb.TIER,Vector2(600,650))
    stale.set_physics_process(false)
    stale.advance_fuse(5)
    game.restart_game()
    var fresh = game._spawn(2,Vector2(650,650))
    await process_frame
    check(is_instance_valid(fresh) and not fresh.destroy_pending,"Restart discards a queued detonation from the previous run")
    var resting = game._spawn(Session.Bomb.TIER,Vector2(800,game.tank_rect.end.y-72))
    resting.sleeping = true
    for frame in range(305): await physics_frame
    check(not is_instance_valid(resting),"A sleeping bomb still detonates after five seconds of real physics ticks")
    game.return_title()
    check(get_nodes_in_group("plushies").is_empty(),"Leaving a run clears every active bomb and plushie")
    game.queue_free()
    for frame in range(8): await process_frame
    OS.delay_msec(250)
    print("Bomb assertions: ",assertions)
    if failures.is_empty(): print("PASS: bomb probability, preview, five-second fuse, contacts, pause, merge races and reset.")
    quit(0 if failures.is_empty() else 1)
