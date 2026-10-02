extends SceneTree
## 다시하기 회귀 검사: 실제 투하로 게임오버까지 진행 → 결과 화면의 '다시 하기' 버튼 클릭 →
## 새 판은 0점에서 시작하고, 투하 없이 기다리는 동안 점수가 오르지 않아야 합니다.
## 화면에 표시되는 점수(HUD)도 함께 확인합니다. 몇 판 연속으로 반복합니다.
const Balls := preload("res://data/balls.gd")
var failures: Array[String] = []
var game: Node

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func frames(count: int) -> void:
	for index in range(count): await physics_frame

func _initialize() -> void:
	_run.call_deferred()

func _find_button(node: Node, button_name: String) -> Button:
	if node is Button and node.name == button_name and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found := _find_button(child, button_name)
		if found != null: return found
	return null

func _play_until_game_over(seed_value: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for step in range(400):
		if game.routes.route == "debrief": return true
		game.aim_x = rng.randf_range(game.tank_rect.position.x, game.tank_rect.end.x)
		game._clamp_aim()
		game.request_drop()
		await frames(36)
	for wait in range(300):
		if game.routes.route == "debrief": return true
		await frames(1)
	return game.routes.route == "debrief"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.start_stage(0)
	await frames(5)
	for round_index in range(3):
		var over: bool = await _play_until_game_over(100 + round_index)
		check(over, "%d판: 실제 투하로 게임오버" % (round_index + 1))
		if not over: break
		var final_score: int = game.score
		await frames(60)
		check(game._hud._score_label.text == str(final_score), "%d판: 결과 직전 화면 점수 = 실제 점수 (%s)" % [round_index + 1, game._hud._score_label.text])
		check(game.score == final_score, "%d판: 결과 화면에서 점수 고정 (%d → %d)" % [round_index + 1, final_score, game.score])
		var button := _find_button(game._hud, "RestartButton")
		check(button != null, "%d판: 결과 화면 '다시 하기' 버튼" % (round_index + 1))
		if button == null: break
		button.pressed.emit()
		await frames(1)
		check(game.routes.route == "gameplay", "%d판: 다시 하기 → 게임 화면" % (round_index + 1))
		check(game.score == 0, "%d판: 다시 시작하면 0점 (%d)" % [round_index + 1, game.score])
		var max_seen := 0
		var max_shown := 0
		for wait in range(300):
			await process_frame
			max_seen = maxi(max_seen, game.score)
			max_shown = maxi(max_shown, int(game._hud._score_label.text))
		check(max_seen == 0, "%d판: 투하 없이 5초 동안 점수 그대로 (최대 %d)" % [round_index + 1, max_seen])
		check(max_shown == 0 and game._hud._score_label.text == "0", "%d판: 화면 점수도 0 그대로 (최대 표시 %d)" % [round_index + 1, max_shown])
		check(game.get_board_toys().size() == 0, "%d판: 새 판 용기는 비어 있음 (%d개)" % [round_index + 1, game.get_board_toys().size()])
		check(game.drop_count == 0, "%d판: 투하 횟수 0에서 시작 (%d)" % [round_index + 1, game.drop_count])
	print("RESULT %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
