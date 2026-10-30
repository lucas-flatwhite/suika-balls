extends SceneTree
## Run with --headless --audio-driver Dummy --fixed-fps 60 --path . --script ...
## Headless CPU/work-count probe, not a browser FPS or GPU benchmark.
const LocalMatch := preload("res://scripts/multiplayer/local_match.gd")
const BallIcon := preload("res://scripts/ui/ball_icon.gd")
const Feedback := preload("res://scripts/vfx/feedback.gd")
const TICKS := 600
const SAMPLES := 7

class CountingBoard extends "res://scripts/game/board_simulation.gd":
	var snapshot_calls := 0
	func snapshot() -> Dictionary:
		snapshot_calls += 1
		return super.snapshot()

var draws := {"icon": 0, "feedback": 0}

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for unused in range(count):
		await process_frame
		RenderingServer.force_draw()

func _run() -> void:
	var icon := BallIcon.new()
	icon.size = Vector2(64, 64)
	icon.tier = 7
	root.add_child(icon)
	icon.draw.connect(func(): draws.icon += 1)
	var fx := Feedback.new()
	root.add_child(fx)
	fx.draw.connect(func(): draws.feedback += 1)
	await frames(4)
	draws.icon = 0
	draws.feedback = 0
	for unused in range(60):
		icon.tier = 7
		await frames(1)
	var controller := LocalMatch.new()
	root.add_child(controller)
	for slot in range(2):
		var viewport := SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(viewport)
		var board := CountingBoard.new()
		viewport.add_child(board)
		board.start_duel(123)
		board.set_physics_process(false)
		for index in range(80):
			var toy = board._spawn(index % 10, Vector2(200 + index % 8 * 50, 400 + index / 8 * 40))
			assert(toy != null)
		board.stop()
		controller.boards.append(board)
		controller.viewports.append(viewport)
	controller.state.status = "playing"
	controller._ends_at = 10000.0
	# Warm caches, then report the median of seven identical 600-tick batches.
	for unused in range(60): controller._physics_process(1.0 / 60.0)
	var timings: Array[float] = []
	var calls := 0
	for sample in range(SAMPLES):
		for board in controller.boards: board.snapshot_calls = 0
		var start := Time.get_ticks_usec()
		for unused in range(TICKS): controller._physics_process(1.0 / 60.0)
		timings.append((Time.get_ticks_usec() - start) / 1000.0)
		calls = controller.boards[0].snapshot_calls + controller.boards[1].snapshot_calls
	timings.sort()
	print("BENCHMARK ", JSON.stringify({"idle_frames": 60, "icon_draws": draws.icon,
		"empty_feedback_draws": draws.feedback, "balls_per_board": 80,
		"physics_ticks": TICKS, "board_snapshot_calls": calls,
		"cpu_ms_median": timings[SAMPLES / 2], "cpu_ms_samples": timings}))
	controller.stop()
	controller.queue_free()
	icon.queue_free()
	fx.queue_free()
	await frames(3)
	quit()
