extends SceneTree
## 비치볼 머지 규칙 자동 검사: 크기 단조 증가, 투하 풀, 합체/점수, 비치볼 보너스,
## 데드라인 게임오버(1초 유예·2초 판정), 연타 방지, 더미 안정화, 최고 점수 저장.
const Balls := preload("res://data/balls.gd")
const BestScore := preload("res://scripts/score/best_score.gd")
var failures: Array[String] = []
var game: Node

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func frames(count: int) -> void:
	for index in range(count): await physics_frame

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# 1. Config
	var monotonic := true
	for tier in range(1, Balls.count()):
		if Balls.radius(tier) <= Balls.radius(tier - 1): monotonic = false
	check(Balls.count() == 10 and monotonic, "공 10단계, 지름 단조 증가")
	check(is_equal_approx(Balls.radius(0) * 2.0 / Balls.CONTAINER_WIDTH, 0.08) and is_equal_approx(Balls.radius(9) * 2.0 / Balls.CONTAINER_WIDTH, 0.54), "지름 비율 8%~54%")
	check(Balls.validate(), "설정 파일 검증")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.start_stage(0)
	await frames(2)
	check(game.routes.route == "gameplay", "시작 → 게임 화면")
	# 2. Drop pool 1..5 and small more often.
	var counts := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var probe = load("res://scripts/core/session.gd").new()
	probe.start(load("res://data/stages/registry.gd").STAGES[0])
	for index in range(5000):
		counts[probe.next_tier()] += 1
		probe.record_drop()
	check(counts[5] + counts[6] + counts[7] + counts[8] + counts[9] == 0, "투하는 1~5단계만")
	check(counts[0] > counts[2] and counts[2] > counts[4], "작은 공이 더 자주 (%s)" % str(counts.slice(0, 5)))
	# 3. Drop cooldown
	game._input_guard = 0
	var before: int = game.drop_count
	game.request_drop()
	game.request_drop()
	check(game.drop_count == before + 1, "연타 시 한 번만 투하")
	await frames(20)
	game.request_drop()
	check(game.drop_count == before + 1, "0.33초 안에는 다음 투하 불가")
	await frames(20)
	game.request_drop()
	check(game.drop_count == before + 2, "0.5초 뒤 다음 투하 가능")
	# 4. Merge + score
	game._clear_run()
	game.start_stage(0)
	await frames(2)
	var score0: int = game.score
	var a = game._spawn(3, Vector2(300, 900))
	var b = game._spawn(3, Vector2(300 + Balls.radius(3) * 2.0 + 1, 900))
	a.linear_velocity = Vector2(200, 0)
	b.linear_velocity = Vector2(-200, 0)
	await frames(40)
	var tiers: Array = []
	for toy in game.get_board_toys(): tiers.append(toy.tier)
	check(tiers.count(4) == 1 and tiers.count(3) == 0, "야구공 2개 → 소프트볼 1개 (%s)" % str(tiers))
	check(game.score - score0 == Balls.score_of(4), "합체 점수 = 새 공 점수 (+%d)" % (game.score - score0))
	check(game.discovered[4], "진화 줄에 소프트볼 표시")
	# 5. Beach ball pair
	game._clear_run()
	game.start_stage(0)
	await frames(2)
	var s1: int = game.score
	var r := Balls.radius(9)
	game._spawn(9, Vector2(60 + r, 1020 - r))
	game._spawn(9, Vector2(60 + r * 3.0 + 2.0, 1020 - r))
	var count_before: int = game.get_board_toys().size()
	await frames(90)
	var beach := 0
	for toy in game.get_board_toys(): if toy.tier == 9: beach += 1
	check(beach == 0, "비치볼 2개 → 둘 다 사라짐")
	check(game.score - s1 == Balls.FINAL_BONUS, "비치볼 보너스 +100 (+%d)" % (game.score - s1))
	# 6. Deadline
	game._clear_run()
	game.start_stage(0)
	await frames(2)
	var high = game._spawn(4, Vector2(360, 250))
	high.freeze = true
	high.age = 0.0
	await frames(54)
	check(game.overflow_time == 0.0, "떨어뜨린 지 1초 안 된 공은 판정 제외")
	await frames(30)
	check(game.danger_warning, "데드라인 넘으면 경고")
	check(game.routes.route == "gameplay", "2초 전에는 게임오버 아님")
	await frames(110)
	check(game.routes.route == "debrief", "데드라인 2초 이상 → 게임오버")
	# 7. Settle: pile of random balls must rest.
	game._clear_run()
	game.start_stage(0)
	await frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for index in range(26):
		var tier := rng.randi_range(0, 6)
		game._spawn(tier, Vector2(rng.randf_range(110, 610), 400 + float(index % 6) * 70))
		await frames(4)
	await frames(240)
	var fastest := 0.0
	for toy in game.get_board_toys(): fastest = maxf(fastest, toy.linear_velocity.length())
	await frames(60)
	var fastest_later := 0.0
	for toy in game.get_board_toys(): fastest_later = maxf(fastest_later, toy.linear_velocity.length())
	check(fastest_later < 20.0, "공 더미가 가라앉음 (최대 속도 %.1f → %.1f)" % [fastest, fastest_later])
	# 8. Best score persistence
	var store := BestScore.new()
	store.path = "user://test_best.json"
	store.load_data()
	store.submit(store.value + 123)
	var expected := store.value
	var again := BestScore.new()
	again.path = "user://test_best.json"
	again.load_data()
	check(again.value == expected, "최고 점수 저장/불러오기")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_best.json"))
	print("RESULT %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
