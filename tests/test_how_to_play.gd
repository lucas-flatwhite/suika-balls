extends SceneTree
## Instructions belong to the title; live games never display onboarding or rescue notices.
var game: Node
var canvas: SubViewport
var assertions := 0
var failures: Array[String] = []
var destination := ""
var save_paths: Array[String] = []
const HELP_KEYS := ["ui.help_body","help.rules","help.bombs","help.rescue","help.input.keyboard","help.input.pointer","help.input.touch","help.input.gamepad"]

func _initialize() -> void: call_deferred("run")

func check(value: bool,message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in range(6): await process_frame

func shot(label: String) -> void:
	if destination.is_empty(): return
	await settle()
	if label.begins_with("gameplay-"): resume_native_fixture()
	RenderingServer.force_draw(false)
	var image := canvas.get_texture().get_image()
	check(image != null and not image.is_empty(),"Native image available: "+label)
	if image != null and not image.is_empty(): check(image.save_png(destination.path_join(label+".png")) == OK,"Capture saved: "+label)

func resume_native_fixture() -> void:
	# A second native test window can trigger the real OS-focus pause. Resume it
	# before measuring this fixture; runtime focus-loss protection stays enabled.
	if not destination.is_empty():
		game.device.app_visible = true
		if game.routes.modal() == "pause": game.close_modal()

func press_h() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_H
	game._unhandled_input(event)

func no_instruction_overlay(context: String) -> void:
	check(not game._hud.controls.has("ui.skip") and not game._hud.controls.has("ui.replay") and not game._hud.controls.has("ui.help"),context+": no instruction controls")
	check(not game._hud.metrics.has("input_hint"),context+": no gameplay instruction line")
	for property in game.get_property_list():
		check(property.name not in ["tutorial","rescue_notice_remaining"],context+": no removed runtime state")
	check(not game.has_method("replay_tutorial") and not game.has_method("dismiss_rescue_notice"),context+": no obsolete tutorial methods")
	check(game._hud.find_children("*Tutorial*","",true,false).is_empty(),context+": no tutorial nodes")

func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		destination = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(destination)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1440,900)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://scenes/main.tscn").instantiate()
	var prefix := "user://how-to-play-"+str(Time.get_ticks_usec())
	for key in ["settings","leaderboard"]:
		var path: String = prefix+"-"+str(key)+".json"
		game.get(key).path = path
		save_paths.append(path)
	game.tweaks.enabled = false
	canvas.add_child(game)
	await settle()
	game.audio.set_muted(true)
	for locale in ["en","zh_CN"]:
		game.setting("locale",locale)
		for size in [Vector2i(1440,900),Vector2i(800,600),Vector2i(390,844),Vector2i(320,568)]:
			canvas.size = size
			game.device.force_mobile = 1 if size.x < 500 else 0
			game.device.safe_insets = Vector4(0,12,8,8) if size.x < 500 else Vector4.ZERO
			game.return_title()
			game._viewport_changed()
			await settle()
			var suffix := "%s-%dx%d" % [locale,size.x,size.y]
			check(game._hud.controls.has("ui.help"),"Title exposes How to play: "+suffix)
			var run_id: String = game.session.run_id
			var score: int = game.score
			game._hud.controls["ui.help"].pressed.emit()
			await settle()
			check(game.routes.route == "title" and game.routes.modal() == "help","How to play stays on title: "+suffix)
			var surface: Control = game._hud.active_surface()
			var texts: Array[String] = []
			for label in surface.find_children("*","Label",true,false): texts.append(label.text)
			for key in HELP_KEYS:
				check(game.t(key) != key and texts.has(game.t(key)),"Help contains localized "+key+": "+suffix)
				for character in game.t(key):
					if character.unicode_at(0) > 127: check(game.locale.font.has_char(character.unicode_at(0)),"Help font covers "+character)
			var buttons := surface.find_children("*","BaseButton",true,false)
			check(buttons.size() == 1 and buttons[0] == game._hud.controls["ui.close"],"Help only offers return navigation: "+suffix)
			for scroll in surface.find_children("*","ScrollContainer",true,false):
				check(scroll.scroll_vertical == 0,"Help opens at the beginning: "+suffix)
				check(not scroll.is_ancestor_of(game._hud.controls["ui.close"]),"Close stays outside the scrolling help content")
			await shot("help-"+suffix)
			for scroll in surface.find_children("*","ScrollContainer",true,false): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			await settle()
			check(Rect2(Vector2.ZERO,canvas.size).encloses(game._hud.controls["ui.close"].get_global_rect()),"Help remains dismissible at scroll end: "+suffix)
			await shot("help-bottom-"+suffix)
			game.close_modal()
			await settle()
			check(game.routes.route == "title" and game.session.run_id == run_id and game.score == score,"Reading help cannot start or change a run: "+suffix)
			press_h()
			check(game.routes.modal() == "help","H opens help from title")
			press_h()
			check(game.routes.modal().is_empty(),"H closes title help")
			game.open_modal("settings")
			game.open_modal("help")
			check(game.routes.modal() == "settings" and game.routes.stack.size() == 1,"Help cannot replace another title modal")
			game.close_modal()
			check(game.start_stage(0),"Start normal solo game")
			await settle()
			resume_native_fixture()
			no_instruction_overlay("New run "+suffix)
			var board: Rect2 = game.board_screen_rect
			var elapsed: float = game.session.elapsed
			game.open_modal("help")
			press_h()
			check(game.routes.modal().is_empty() and not game.is_frozen(),"Help APIs and H cannot interrupt gameplay: "+suffix)
			game._physics_process(0.1)
			check(game.session.elapsed > elapsed,"Gameplay timer continues without instructional waits: "+suffix)
			game.request_drop()
			game._advance_claw(game.active_open_seconds+0.01)
			var first = game._spawn(0,Vector2(650,game.tank_rect.end.y-150))
			var second = game._spawn(0,Vector2(730,game.tank_rect.end.y-150))
			game._merge(first,second,game._run_generation)
			await settle()
			no_instruction_overlay("After first drop and merge "+suffix)
			check(game.board_screen_rect == board,"First actions never reserve tutorial space")
			game.open_modal("pause")
			await settle()
			check(not game._hud.controls.has("ui.help"),"Pause omits How to play")
			press_h()
			check(game.routes.modal() == "pause","H cannot replace pause")
			game.close_modal()
			await shot("gameplay-"+suffix)
			game.restart_game()
			await settle()
			no_instruction_overlay("Restart "+suffix)
	game.queue_free()
	await settle()
	for path in save_paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await create_timer(0.25).timeout
	print("HOW_TO_PLAY assertions=%d failures=%d" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
