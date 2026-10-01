extends SceneTree
## Exercises the offline authority with the real shared duel-board physics.
const LocalMatch = preload("res://scripts/multiplayer/local_match.gd")
const Protocol = preload("res://scripts/multiplayer/protocol.gd")

var assertions := 0
var failures: Array[String] = []
var snapshots: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for unused in range(count):
		await physics_frame
		await process_frame

func until_phase(controller: Node, phase: String, maximum_frames: int = 360) -> bool:
	for unused in range(maximum_frames):
		if controller.state.status == phase:
			check(true, "Match enters " + phase)
			return true
		await frames(1)
	check(false, "Match enters " + phase)
	return false

func overflow_board(board: Node) -> void:
	# Cross the actual danger-line branch, including freezing the physical pile.
	var marker = board._spawn(8, Vector2(720.0, board.danger_y() - 80.0))
	marker.age = 2.0
	marker.danger_time = float(board.tweaks.value("gameplay.overflow_seconds"))
	marker.linear_velocity = Vector2.ZERO
	board._physics_process(1.0 / 60.0)
	check(board.session.outcome == "defeat" and board.session.reason == "overflow" and marker.freeze, "Danger line defeats and freezes its own board")

func check_survivor_round(controller: Node, first_defeated: int) -> void:
	var defeated = controller.boards[first_defeated - 1]
	var survivor_id := 3 - first_defeated
	var survivor = controller.boards[survivor_id - 1]
	defeated.session.score.total = 10000
	var merge_a = defeated._spawn(0, Vector2(520, 700))
	var merge_b = defeated._spawn(0, Vector2(660, 700))
	var bomb = defeated._spawn(defeated.BombDefinition.TIER, Vector2(1000, 650))
	var victim = defeated._spawn(2, Vector2(990, 650))
	defeated.request_merge(merge_a, merge_b)
	defeated.request_bomb_detonation(bomb, [victim])
	overflow_board(defeated)
	var frozen_aim: float = defeated.aim_x
	var frozen_elapsed: float = defeated.session.elapsed
	controller.send_input(first_defeated, 500.0, true)
	defeated.request_merge(merge_a, merge_b)
	check(defeated.session.merge(3) == 0, "Defeated session rejects further scoring")
	await frames(6)
	check(controller.state.status == "playing" and controller.state.winner_id == 0 and controller.state.result_reason == "", "Player %d overflow leaves the round playing without declaring a winner" % first_defeated)
	check(defeated.is_frozen() and not survivor.is_frozen() and controller.is_physics_processing(), "Only Player %d is frozen after their overflow" % first_defeated)
	check(defeated.aim_x == frozen_aim and defeated.drop_count == 0 and defeated.session.elapsed == frozen_elapsed, "Defeated player cannot aim, drop, or advance their board clock")
	check(defeated.score == 10000 and defeated.merge_count == 0 and is_instance_valid(merge_a) and is_instance_valid(merge_b) and not merge_a.merge_locked and not merge_b.merge_locked, "Overflow cancels queued merges without awarding points")
	check(is_instance_valid(bomb) and is_instance_valid(victim) and not bomb.destroy_pending and not victim.destroy_pending and not bomb.detonation_requested, "Overflow cancels a queued blast and preserves its bodies")
	var frozen_pile: Array = defeated.snapshot().toys.duplicate(true)
	var frozen_fuse: float = bomb.fuse_remaining
	var remaining_before: float = controller.state.remaining_seconds
	check(controller.state.boards[first_defeated - 1].outcome == "defeat" and not controller.state.boards[first_defeated - 1].can_drop and controller.state.boards[survivor_id - 1].can_drop, "Live snapshots distinguish defeated and playable boards")
	controller.send_input(survivor_id, 930.0, true)
	await frames(65)
	check(survivor.aim_x == 930.0 and survivor.drop_count == 1 and survivor.get_board_toys().size() == 1, "Surviving Player %d can still move and drop" % survivor_id)
	var live_a = survivor._spawn(0, Vector2(520, 700))
	var live_b = survivor._spawn(0, Vector2(660, 700))
	survivor.request_merge(live_a, live_b)
	await frames(6)
	check(survivor.merge_count >= 1 and survivor.score > 0, "Surviving player still merges and earns points")
	check(controller.state.status == "playing" and controller.state.remaining_seconds < remaining_before, "Shared countdown continues while one player remains active")
	check(defeated.snapshot().toys == frozen_pile and bomb.fuse_remaining == frozen_fuse and defeated.score == 10000, "Defeated board keeps its exact pile, bomb fuse, and final score while the other player continues")
	controller.request_rematch()
	check(controller.state.status == "playing" and controller.boards[first_defeated - 1] == defeated, "A defeated player cannot restart a round while their opponent is playing")
	overflow_board(survivor)
	await until_phase(controller, "finished", 6)
	check(controller.state.winner_id == first_defeated and controller.state.result_reason == "overflow", "First-defeated Player %d still wins with the higher final score once both overflow" % first_defeated)
	check(controller.state.boards[0].outcome == "defeat" and controller.state.boards[1].outcome == "defeat" and not controller.state.boards[0].can_drop and not controller.state.boards[1].can_drop, "Both defeats are preserved in the final result snapshot")
	var remaining: float = controller.state.remaining_seconds
	await frames(8)
	check(controller.state.remaining_seconds == remaining and remaining > 0.0, "Both-overflow result freezes the remaining match time")

func run() -> void:
	var controller := LocalMatch.new()
	root.add_child(controller)
	controller.state_changed.connect(func(next: Dictionary): snapshots.append(next))
	check(controller.countdown_seconds == 3.0 and controller.match_seconds == 180.0, "Default clocks preserve the three-minute local duel")
	check(controller.state.status == "idle" and not controller.is_physics_processing(), "Idle controller does not tick")
	controller.countdown_seconds = 0.2
	controller.match_seconds = 5.0
	controller.seed_value = 14327
	controller.start_match()
	check(controller.state.status == "countdown" and is_equal_approx(controller.state.countdown, 0.2), "Starting emits the full configured countdown")
	check(not controller.state.connected and controller.state.room_code == "" and controller.state.queue_mode == "local", "Local match has no server or room connection")
	check(controller.state.player_id == 1 and controller.state.players[0].id == 1 and controller.state.players[1].id == 2, "Player identity fixes left and right ownership")
	check(controller.state.boards.size() == 2 and controller.state.boards[0].player_id == 1 and controller.state.boards[1].player_id == 2, "Snapshots preserve both board owners")
	check(controller.boards.size() == 2 and controller.viewports.size() == 2, "One local round creates exactly two boards")
	var a = controller.boards[0]
	var b = controller.boards[1]
	check(a.get_world_2d() != b.get_world_2d(), "Players have independent physics worlds")
	check(a.held_tier == b.held_tier and a.next_tier == b.next_tier, "Players receive the same seeded supply")
	check(a.is_frozen() and b.is_frozen() and not controller.state.boards[0].can_drop, "Countdown freezes both boards")
	controller.send_input(1, 500.0, true)
	controller.send_input(2, 900.0, true)
	check(a.aim_x == 720.0 and b.aim_x == 720.0 and a.drop_count == 0 and b.drop_count == 0, "Countdown rejects movement and drops")
	controller.start_match()
	controller.request_rematch()
	check(controller.boards[0] == a and controller.state.match_epoch == 1, "Repeated start and early rematch cannot reset an active countdown")
	snapshots[0].boards[0].score = 987654
	check(controller.state.boards[0].score == 0, "Emitted snapshots cannot mutate controller state")
	if not await until_phase(controller, "playing", 30):
		controller.stop()
		quit(1)
		return
	check(not a.is_frozen() and not b.is_frozen(), "Countdown activates both boards together")
	check(controller.state.remaining_seconds <= 5.0 and controller.state.remaining_seconds > 4.8, "Match clock starts after countdown")
	controller.send_input(1, 510.0)
	check(a.aim_x == 510.0 and b.aim_x == 720.0, "Player 1 movement only changes the left board")
	controller.send_input(2, 930.0)
	check(a.aim_x == 510.0 and b.aim_x == 930.0, "Player 2 movement only changes the right board")
	controller.send_input(0, 700.0, true)
	controller.send_input(3, 700.0, true)
	controller.send_input(1, NAN, true)
	controller.send_input(2, INF, true)
	check(a.aim_x == 510.0 and b.aim_x == 930.0 and a.drop_count == 0 and b.drop_count == 0, "Invalid owners and non-finite input are rejected")
	controller.send_input(1, -100000.0)
	controller.send_input(2, 100000.0)
	check(a.aim_x >= Protocol.AIM_MIN and b.aim_x <= Protocol.AIM_MAX, "Both players stay inside protocol aim bounds")
	controller.send_input(1, 510.0, true)
	await frames(65)
	check(a.drop_count == 1 and b.drop_count == 0 and a.get_board_toys().size() == 1 and b.get_board_toys().is_empty(), "Player 1 releases only the left payload")
	controller.send_input(2, 930.0, true)
	await frames(65)
	check(a.drop_count == 1 and b.drop_count == 1 and b.get_board_toys().size() == 1, "Player 2 releases only the right payload")
	check(controller.state.boards[0].ack_seq > 0 and controller.state.boards[1].ack_seq > 0, "Both snapshots acknowledge their own accepted inputs")
	var snapshot_count := snapshots.size()
	await frames(60)
	var emitted := snapshots.size() - snapshot_count
	check(emitted >= 19 and emitted <= 21, "Playing publishes at the shared 20 Hz snapshot cadence")
	b.session.score.total = 25
	if not await until_phase(controller, "finished"):
		controller.stop()
		quit(1)
		return
	check(controller.state.winner_id == 2 and controller.state.result_reason == "time", "Higher Player 2 score wins when the shared timer expires")
	check(is_zero_approx(controller.state.remaining_seconds), "Timed result freezes the clock at zero")
	check(a.is_frozen() and b.is_frozen() and not controller.is_physics_processing(), "Finished match stops both physics boards and controller clock")
	var final_left_aim: float = a.aim_x
	controller.send_input(1, 720.0, true)
	check(a.aim_x == final_left_aim and a.drop_count == 1, "Finished matches reject input")
	var old_viewports: Array = controller.viewports.duplicate()
	controller.request_rematch()
	check(controller.state.status == "countdown" and controller.state.match_epoch == 2, "One shared rematch restarts both players with a new epoch")
	check(controller.state.winner_id == 0 and controller.state.result_reason == "" and controller.state.boards[0].score == 0 and controller.state.boards[1].score == 0, "Rematch clears both scores and previous result")
	check(controller.state.boards[0].drops == 0 and controller.state.boards[1].drops == 0 and controller.state.boards[0].toys.is_empty() and controller.state.boards[1].toys.is_empty(), "Rematch clears both piles and drop histories")
	await frames(2)
	check(not is_instance_valid(old_viewports[0]) and not is_instance_valid(old_viewports[1]), "Rematch releases both previous physics worlds")
	await until_phase(controller, "playing", 30)
	await check_survivor_round(controller, 1)
	controller.request_rematch()
	await until_phase(controller, "playing", 30)
	check(controller.state.boards[0].outcome == "" and controller.state.boards[1].outcome == "" and not controller.boards[0].is_frozen() and not controller.boards[1].is_frozen(), "Rematch revives both defeated boards")
	await check_survivor_round(controller, 2)
	for case in [{"scores": [200, 100], "winner": 1}, {"scores": [100, 200], "winner": 2}, {"scores": [200, 200], "winner": -1}]:
		controller.request_rematch()
		await until_phase(controller, "playing", 30)
		for slot in range(2):
			controller.boards[slot].session.score.total = case.scores[slot]
			overflow_board(controller.boards[slot])
		await until_phase(controller, "finished", 6)
		check(controller.state.winner_id == case.winner and controller.state.result_reason == "overflow", "Same-frame defeats rank final scores %s, with equal scores drawing" % str(case.scores))
	controller.match_seconds = 0.15
	for defeated_id in [1, 2]:
		for result in ["defeated_leads", "survivor_leads", "draw"]:
			controller.request_rematch()
			await until_phase(controller, "playing", 30)
			var survivor_id: int = 3 - defeated_id
			controller.boards[defeated_id - 1].session.score.total = 100 if result == "survivor_leads" else 200
			controller.boards[survivor_id - 1].session.score.total = 100 if result == "defeated_leads" else 200
			overflow_board(controller.boards[defeated_id - 1])
			await until_phase(controller, "finished", 30)
			var expected: int = -1 if result == "draw" else (defeated_id if result == "defeated_leads" else survivor_id)
			check(controller.state.winner_id == expected and controller.state.result_reason == "time", "Timer ranks scores with Player %d defeated: %s" % [defeated_id, result])
			check(controller.state.boards[defeated_id - 1].outcome == "defeat" and controller.state.boards[survivor_id - 1].outcome == "" and not controller.state.boards[survivor_id - 1].can_drop and is_zero_approx(controller.state.remaining_seconds), "Timeout preserves individual board outcomes and stops the surviving player")
	controller.match_seconds = 0.1
	controller.request_rematch()
	await until_phase(controller, "finished", 30)
	check(controller.state.winner_id == -1 and controller.state.result_reason == "time", "Equal scores produce a timed draw")
	controller.request_rematch()
	await until_phase(controller, "playing", 30)
	controller.boards[0].session.score.total = 50
	await until_phase(controller, "finished", 30)
	check(controller.state.winner_id == 1 and controller.state.result_reason == "time", "Higher Player 1 score wins when time expires")
	old_viewports = controller.viewports.duplicate()
	controller.stop()
	controller.stop()
	check(controller.state.status == "idle" and controller.boards.is_empty() and controller.viewports.is_empty() and not controller.is_physics_processing(), "Stop is idempotent and clears all match ownership")
	await frames(2)
	check(not is_instance_valid(old_viewports[0]) and not is_instance_valid(old_viewports[1]) and get_nodes_in_group("plushies").is_empty(), "Stop releases every viewport and toy")
	controller.start_match()
	check(controller.state.match_epoch == 1 and controller.state.status == "countdown", "A stopped controller can start a clean new session")
	old_viewports = controller.viewports.duplicate()
	controller.queue_free()
	await frames(3)
	check(not is_instance_valid(old_viewports[0]) and not is_instance_valid(old_viewports[1]) and get_nodes_in_group("plushies").is_empty(), "Removing the controller cleans root-owned physics worlds")
	print("Local match assertions: ", assertions)
	if failures.is_empty():
		print("PASS: offline match ownership, input, clocks, results, rematch and cleanup.")
	quit(0 if failures.is_empty() else 1)
