extends SceneTree
## 다국어(한국어·영어) 검사: 키/자리표시자 일치, 첫 실행 언어 감지, 저장된 선택 복원,
## 게임 중 전환(진행 상태 유지), 공 이름·동적 문구, 내보낸 카탈로그 읽기.
const Balls := preload("res://data/balls.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Localization := preload("res://scripts/core/localization.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func frames(count: int) -> void:
	for index in range(count): await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _texts(node: Node, out: Array) -> void:
	if node is Label or node is Button: out.append(String(node.text))
	for child in node.get_children(): _texts(child, out)

func _run() -> void:
	# 1. 카탈로그 일치
	var ko: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ko.json"))
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/en.json"))
	var missing := []
	var mismatched := []
	var hangul_in_en := []
	var regex := RegEx.create_from_string("\\{\\w+\\}")
	for key in ko:
		if String(key).begins_with("tweak.") or String(key).begins_with("category.") or String(key).begins_with("unit."): continue
		if not en.has(key): missing.append(key); continue
		var a := []; var b := []
		for m in regex.search_all(String(ko[key])): a.append(m.get_string())
		for m in regex.search_all(String(en[key])): b.append(m.get_string())
		a.sort(); b.sort()
		if a != b: mismatched.append(key)
		if key != "ui.language_switch":
			for ch in String(en[key]):
				if ch >= "가" and ch <= "힣": hangul_in_en.append(key); break
	for key in en:
		if not ko.has(key): missing.append("ko:" + key)
	check(missing.is_empty(), "영어/한국어 키 일치 %s" % [missing])
	check(mismatched.is_empty(), "자리표시자 일치 %s" % [mismatched])
	check(hangul_in_en.is_empty(), "영어 문구에 한글 없음 %s" % [hangul_in_en])

	# 2. 첫 실행 언어 감지와 저장값 검증
	check(Settings.detect_locale("ko_KR") == "ko" and Settings.detect_locale("ko") == "ko", "ko* → 한국어")
	check(Settings.detect_locale("en_US") == "en" and Settings.detect_locale("ja_JP") == "en" and Settings.detect_locale("") == "en", "그 밖의 언어 → 영어")
	var s := Settings.new()
	s.path = "user://test_i18n_settings.json"
	if FileAccess.file_exists(s.path): DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.load_data()
	s.apply_detected_locale("en_US")
	check(s.values.locale == "en" and not s.locale_saved, "저장된 선택이 없으면 감지값 사용")
	check(not s.set_value("locale", "zh_CN"), "지원하지 않는 언어 거부")
	check(s.set_value("locale", "ko"), "언어 선택 저장")
	var again := Settings.new()
	again.path = s.path
	again.load_data()
	again.apply_detected_locale("en_US")
	check(again.values.locale == "ko" and again.locale_saved, "다시 불러와도 저장된 선택(한국어)이 감지값보다 우선")

	# 3. 번역 서비스와 공 이름
	var loc := Localization.new()
	loc.set_locale("en")
	check(loc.t("ui.start") == "Start" and Balls.name_of(7) == "Basketball", "영어: 문구와 공 이름")
	check(loc.t("ui.new_ball", {"ball": Balls.name_of(7)}) == "NEW! Basketball", "영어: NEW 알림 동적 문구")
	check(loc.t("tweak.ui.text.scale.label") == "글자 크기", "개발용 Tweak 문구는 한국어로 대체")
	loc.set_locale("ko")
	check(loc.t("ui.start") == "시작하기" and Balls.name_of(7) == "농구공", "한국어: 문구와 공 이름")
	check(Localization.normalize("en_US") == "en" and Localization.normalize("ko_KR") == "ko", "언어 ID 정규화")

	# 4. 게임 안에서 전환: 시작 화면 → 게임 중(점수 유지) → 일시정지 메뉴
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.set_language("ko")
	await frames(3)
	var texts := []
	_texts(game._hud, texts)
	check(texts.has("시작하기") and texts.has("English"), "시작 화면 한국어 + English 전환 버튼")
	game.toggle_language()
	await frames(3)
	texts.clear(); _texts(game._hud, texts)
	check(texts.has("Start") and texts.has("한국어") and texts.has("Beach Ball Merge"), "전환 후 시작 화면 영어")
	check(game.settings.values.locale == "en", "선택한 언어 저장")
	game.start_stage(0)
	await frames(10)
	game.session.score.total = 123
	game.set_language("ko")
	await frames(3)
	check(game.score == 123 and game.routes.route == "gameplay", "게임 중 전환해도 점수·진행 유지")
	texts.clear(); _texts(game._hud, texts)
	check(texts.has("점수"), "게임 화면 한국어")
	game.set_language("en")
	await frames(3)
	texts.clear(); _texts(game._hud, texts)
	check(texts.has("Score") and texts.has("Next"), "게임 화면 영어")
	game.open_modal("pause")
	await frames(3)
	texts.clear(); _texts(game._hud, texts)
	check(texts.has("Resume") and texts.has("Language · 한국어"), "일시정지 메뉴 영어 + 언어 버튼")
	game.close_modal()
	game.set_language("ko")
	await frames(2)
	print("RESULT %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
