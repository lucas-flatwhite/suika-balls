extends SceneTree
## Use real boards and count serialization rather than wall-clock thresholds.
const LocalMatch := preload("res://scripts/multiplayer/local_match.gd")

class CountingBoard extends "res://scripts/game/board_simulation.gd":
	var snapshot_calls := 0
	func snapshot() -> Dictionary:
		snapshot_calls += 1
		return super.snapshot()

var failures: Array[String] = []
var published: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func _run() -> void:
	var controller := LocalMatch.new()
	root.add_child(controller)
	controller.state_changed.connect(func(state: Dictionary): published.append(state))
	for slot in range(2):
		var viewport := SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(viewport)
		var board := CountingBoard.new()
		viewport.add_child(board)
		board.start_duel(123)
		board.stop()
		board.set_physics_process(false)
		controller.boards.append(board)
		controller.viewports.append(viewport)
	controller.state.status = "playing"
	controller._ends_at = 1000.0
	var a: CountingBoard = controller.boards[0]
	var b: CountingBoard = controller.boards[1]
	for unused in range(60): controller._physics_process(1.0 / 60.0)
	var calls := a.snapshot_calls + b.snapshot_calls
	check(published.size() == 20, "60 physics ticks still publish exactly 20 snapshots (%d)" % published.size())
	check(calls == 40, "Only published boards are serialized: 40 calls per second (%d)" % calls)
	check(is_equal_approx(controller.state.remaining_seconds, 999.0), "Shared match clock advances normally")
	published[0].boards[0].score = 98765
	check(controller.state.boards[0].score == 0 and a.score == 0, "Published snapshots remain detached from controller and authority")
	# A single defeated player does not end the match; both defeats do.
	a.session.finish("defeat", "overflow")
	a.session.score.total = 30
	b.session.score.total = 20
	controller._physics_process(1.0 / 60.0)
	check(controller.state.status == "playing", "One overflow preserves the other player's turn")
	b.session.finish("defeat", "overflow")
	controller._physics_process(1.0 / 60.0)
	check(controller.state.status == "finished" and controller.state.winner_id == 1 and controller.state.result_reason == "overflow", "Both overflows resolve using authoritative scores")
	check(controller.state.boards[0].outcome == "defeat" and controller.state.boards[1].outcome == "defeat", "Final snapshot contains both outcomes")
	# Timeout must see fresh scores even without an intervening published snapshot.
	for scores in [[10, 20], [20, 10], [10, 10]]:
		controller.state.status = "playing"
		controller._ends_at = controller._elapsed
		a.session.score.total = scores[0]
		b.session.score.total = scores[1]
		b.session.outcome = ""
		var expected := -1 if scores[0] == scores[1] else (1 if scores[0] > scores[1] else 2)
		controller._physics_process(1.0 / 60.0)
		check(controller.state.winner_id == expected and controller.state.result_reason == "time" and controller.state.remaining_seconds == 0, "Timeout uses current scores %s, including ties" % str(scores))
	controller.stop()
	controller.queue_free()
	for unused in range(3): await process_frame
	check(get_nodes_in_group("plushies").is_empty(), "Match cleanup releases its bodies")
	# Exercise the shipping controller's countdown, independent physics and rematch.
	var live := LocalMatch.new()
	live.countdown_seconds = 0.0
	live.match_seconds = 10.0
	root.add_child(live)
	live.start_match()
	for unused in range(5): await physics_frame
	check(live.state.status == "playing" and live.boards.size() == 2, "Real countdown activates both physics boards")
	live.send_input(1, 510, true)
	live.send_input(2, 930, true)
	for unused in range(50): await physics_frame
	check(live.boards[0].drop_count == 1 and live.boards[1].drop_count == 1, "Both players can drop with the shipping authority")
	check(live.state.boards[0].toys.size() == 1 and live.state.boards[1].toys.size() == 1, "Published snapshots track both real falling balls")
	check(live.boards[0].get_world_2d() != live.boards[1].get_world_2d(), "The two piles retain independent physics worlds")
	live.boards[0].session.finish("defeat", "overflow")
	live.boards[0]._finish_run()
	for unused in range(5): await physics_frame
	check(live.state.status == "playing" and not live.boards[1].is_frozen(), "A real defeated board leaves its opponent active")
	live.boards[1].session.finish("defeat", "overflow")
	live.boards[1]._finish_run()
	for unused in range(5): await physics_frame
	check(live.state.status == "finished", "The shipping authority finishes after both overflows")
	live.request_rematch()
	for unused in range(5): await physics_frame
	check(live.state.status == "playing" and live.state.match_epoch == 2 and live.state.boards[0].toys.is_empty() and live.state.boards[1].toys.is_empty(), "Rematch replaces both piles and resumes snapshots")
	live.stop()
	live.queue_free()
	for unused in range(3): await process_frame
	check(get_nodes_in_group("plushies").is_empty(), "Real match cleanup leaves no physics bodies")
	print("RESULT %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
