extends SceneTree
## The Arcade chip floats over the canvas's top-left corner. Every row that reaches that corner
## starts after it: the gameplay HUD, the title buttons and the duel heading.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func frames(count := 4) -> void:
	for unused in range(count): await process_frame

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.audio.set_muted(true)
	# Phones get the 44px arrow; wider screens get the 96px chip with its word.
	for case in [[Vector2i(390, 664), 44.0, 1], [Vector2i(320, 568), 44.0, 1], [Vector2i(1280, 720), 96.0, 0]]:
		var size: Vector2i = case[0]
		var chip := Rect2(12, 8, case[1], 36)
		var label := "%dx%d" % [size.x, size.y]
		game.device.force_mobile = case[2]
		game.return_title()
		root.size = size
		game.device.arcade_chip = chip
		game._viewport_changed()
		await frames()
		var language: Control = game._hud.find_child("LanguageButton", true, false)
		check(language != null and not language.get_global_rect().intersects(chip), label + ": title language button stays clear of the chip")
		game.start_stage(0)
		await frames()
		var bar: Control = game._hud._score_label.get_parent().get_parent().get_parent()
		var rect := bar.get_global_rect()
		check(not rect.intersects(chip), label + ": gameplay HUD row stays clear of the chip")
		check(rect.end.x <= size.x, label + ": gameplay HUD row stays on screen")
		check(bar.get_combined_minimum_size().x <= rect.size.x + 0.5, label + ": HUD cards fit the room left beside the chip")
		var buttons := bar.find_children("*", "Button", true, false)
		check(buttons.size() == 1, label + ": the HUD row keeps Pause only; sound lives in the pause menu (%d buttons)" % buttons.size())
	# Without a chip, as in native builds, the HUD keeps its whole column.
	game.return_title()
	root.size = Vector2i(390, 664)
	game.device.force_mobile = 1
	game.device.arcade_chip = Rect2()
	game._viewport_changed()
	game.start_stage(0)
	await frames()
	var full: Control = game._hud._score_label.get_parent().get_parent().get_parent()
	check(full.get_global_rect().position.x < 20, "No chip: the HUD row starts at the column edge")
	# The local duel draws its own heading across the top of a desktop window.
	game.return_title()
	root.size = Vector2i(1280, 720)
	game.device.force_mobile = 0
	var desktop_chip := Rect2(12, 8, 96, 36)
	game.device.arcade_chip = desktop_chip
	game._viewport_changed()
	await frames()
	game.open_multiplayer()
	await frames(8)
	var heading: Control = root.find_child("MultiplayerScreenHeading", true, false)
	check(heading != null and not heading.get_global_rect().intersects(desktop_chip), "Duel heading stays clear of the chip")
	if failures.is_empty(): print("PASS: Arcade chip keep-out on phone, small phone, desktop and the local duel")
	quit(1 if not failures.is_empty() else 0)
