extends SceneTree
## 화면 캡처: 시작 화면, 게임 중(모든 공), NEW 알림, 일시정지, 게임오버.
## 사용: godot --path . --resolution 390x844 --script tests/capture_ball_screens.gd -- out_prefix
var game: Node
var prefix := "/tmp/bm"

func frames(count: int) -> void:
	for index in range(count): await process_frame

func shot(name: String) -> void:
	await frames(3)
	var image := root.get_texture().get_image()
	image.save_png("%s_%s.png" % [prefix, name])
	print("saved ", prefix, "_", name)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: prefix = args[0]
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	# 선택: BM_LANG=en|ko 로 캡처 언어 지정
	if OS.get_environment("BM_LANG") != "": game.set_language(OS.get_environment("BM_LANG"))
	await frames(16)
	await shot("title")
	game.start_stage(0)
	await frames(10)
	var tank: Rect2 = game.tank_rect
	var x := tank.position.x
	var y := tank.end.y
	# Lay every tier along the floor in rows.
	var row_x := tank.position.x + 4
	var row_y := tank.end.y
	for tier in [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]:
		var r: float = game.Balls.radius(tier)
		if row_x + r * 2 > tank.end.x:
			row_x = tank.position.x + 4
			row_y -= 280
		var toy = game._spawn(tier, Vector2(row_x + r, row_y - r - 2))
		toy.rotation = 0.6 * tier
		toy.merge_locked = true
		game._mark_seen(tier, tier == 7)
		row_x += r * 2 + 4
	await frames(30)
	for toy in game.get_board_toys(): toy.freeze = true
	game.aim_x = 420
	await shot("play")
	game.open_modal("pause")
	await shot("pause")
	game.close_modal()
	await frames(5)
	game.session.highest = 7
	game.session.finish("defeat", "overflow")
	game._finish_run()
	await frames(10)
	await shot("over")
	quit(0)
