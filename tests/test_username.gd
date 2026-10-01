extends SceneTree
## Exercise the shared profile field through real UI input and isolated save files.
## Optional native evidence: --script tests/test_username.gd -- --capture OUTPUT
const Settings := preload("res://scripts/core/settings.gd")
const Board := preload("res://scripts/score/leaderboard.gd")
var game: Node
var canvas: SubViewport
var assertions := 0
var failures: Array[String] = []
var capture_directory := ""

func _initialize() -> void: call_deferred("run")

func check(value: bool,message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		push_error(message)

func settle(frames := 6) -> void:
	for frame in range(frames): await process_frame

func layout(view: Vector2i,mobile: bool,language := "en") -> void:
	canvas.size = view
	game.device.force_mobile = 1 if mobile else 0
	game.device.safe_insets = Vector4(0,24,0,20) if mobile else Vector4.ZERO
	game.locale.locale = language
	game._viewport_changed()
	if game.multiplayer_active(): game._multiplayer_screen._rebuild()
	await settle()

func field(owner: Node) -> LineEdit:
	var value = owner.find_child("username_input",true,false)
	check(value is LineEdit,"Screen includes its editable username field")
	return value as LineEdit

func verify_field(owner: Node,label: String) -> void:
	var input := field(owner)
	if input == null: return
	var rect := input.get_global_rect()
	check(input.editable and input.is_visible_in_tree(),label+" username is visible and editable")
	check(Rect2(Vector2.ZERO,canvas.size).grow(1).encloses(rect),label+" username fits the viewport")
	check(rect.size.y >= 44,label+" username has a touch-sized target")
	check(input.max_length == 20,label+" username bounds input to 20 characters")
	var parent := input.get_parent()
	while parent != null and parent != owner:
		if parent is ScrollContainer:
			check(parent.get_global_rect().grow(1).encloses(rect),label+" username is visible without scrolling (field %s, panel %s)" % [rect,parent.get_global_rect()])
			var bar: VScrollBar = parent.get_v_scroll_bar()
			check(parent.scroll_vertical >= 0 and parent.scroll_vertical <= maxf(0,bar.max_value-bar.page),label+" focus reveal stays within the valid scroll range")
		parent = parent.get_parent()
	for key in ["mp.local_splitscreen"]:
		if owner.controls.has(key) and owner.controls[key].is_visible_in_tree():
			check(rect.end.y <= owner.controls[key].get_global_rect().position.y+1,label+" username precedes "+key)

func click_input(input: LineEdit) -> void:
	var point := input.get_global_transform_with_canvas()*(input.size*0.5)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		canvas.push_input(event,true)
	await settle(2)
	check(input.has_focus(),"Clicking the username field starts editing")

func key(code: int,unicode_value := 0) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode_value
		event.pressed = pressed
		canvas.push_input(event,true)

func type_name(input: LineEdit,value: String,submit := true) -> void:
	await click_input(input)
	input.select_all()
	key(KEY_BACKSPACE)
	for character in value:
		var codepoint := character.unicode_at(0)
		key(character.to_upper().unicode_at(0) if codepoint < 128 else 0,codepoint)
	await settle(2)
	if submit:
		key(KEY_ENTER)
		await settle(2)
		check(not input.has_focus(),"Enter saves the username and leaves editing")

func verify_saved(expected: String,label: String) -> void:
	check(game.settings.values.name == expected,label+" updates the shared profile")
	var restored := Settings.new()
	restored.path = game.settings.path
	restored.load_data()
	check(restored.values.name == expected,label+" persists across settings reload")

func shot(label: String) -> void:
	if capture_directory.is_empty(): return
	await settle(8)
	RenderingServer.force_draw(false)
	var rendered := canvas.get_texture().get_image()
	check(rendered != null and not rendered.is_empty(),"Rendered "+label)
	if rendered != null and not rendered.is_empty():
		check(rendered.save_png(capture_directory.path_join(label+".png")) == OK,"Saved "+label)

func verify_keyboard_resize(owner: Node,view: Vector2i,mobile: bool,label: String) -> void:
	if not mobile: return
	var input := field(owner)
	if input == null: return
	await click_input(input)
	input.caret_column = mini(3,input.text.length())
	var caret := input.caret_column
	var expected := input.text
	canvas.size = Vector2i(view.x,420 if view.x == 320 else 500)
	game._viewport_changed()
	await settle(10)
	var resized_input := field(owner)
	if resized_input != null:
		check(resized_input.has_focus(),label+" retains input focus when the phone keyboard shrinks the viewport")
		check(resized_input.text == expected and resized_input.caret_column == caret,label+" retains text and caret during keyboard resize")
		verify_field(owner,label+" keyboard")
		await shot("keyboard-"+label.replace(" ","-"))
		key(KEY_ENTER)
	canvas.size = view
	game._viewport_changed()
	await settle()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var capture_index := args.find("--capture")
	if capture_index >= 0:
		capture_directory = args[capture_index+1] if args.size() > capture_index+1 else "res://build/username-captures"
		DirAccess.make_dir_recursive_absolute(capture_directory)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1440,900)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://scenes/main.tscn").instantiate()
	canvas.add_child(game)
	await settle()
	game.settings.path = "user://username-test-settings.json"
	game.leaderboard.path = "user://username-test-board.json"
	game.settings.values = Settings.DEFAULTS.duplicate()
	game.settings.values.muted = true
	game.audio.set_muted(true)
	game.leaderboard.rows.clear()
	game.tweaks.reset_all()
	game.tweaks.enabled = false
	game.setting("name","")
	await layout(Vector2i(1440,900),false)
	game.open_modal("leaderboard")
	await settle()
	var input := field(game._hud)
	if input == null:
		await finish()
		return
	await type_name(input,"  pHmR Mushroom  ",false)
	verify_saved("pHmR Mushroom","Typing on Leaderboard")
	check(game.routes.modal() == "leaderboard" and game.audio_muted,"Typing shortcut letters does not navigate, pause or toggle audio")
	key(KEY_ENTER)
	await settle()
	check(input.text == "pHmR Mushroom" and not input.has_focus(),"Submit displays the canonical saved username")
	game.close_modal()
	game.open_modal("settings")
	await settle()
	input = field(game._hud)
	if input != null:
		check(input.text == "pHmR Mushroom","Settings mirrors the Leaderboard username")
		await type_name(input,"Settings Pilot")
		verify_saved("Settings Pilot","Editing in Settings")
	game.close_modal()
	game.open_multiplayer()
	await settle()
	var screen: Control = game._multiplayer_screen
	input = field(screen)
	if input != null:
		check(input.text == "Settings Pilot" and screen.display_name(true) == "Settings Pilot","Multiplayer opens with the saved shared username")
		await type_name(input,"pHmR Local Pilot")
		verify_saved("pHmR Local Pilot","Editing in Multiplayer")
		check(screen.entry_mode == "choice" and screen.modal_kind.is_empty() and game.audio_muted,"Multiplayer typing leaves navigation and audio unchanged")
		check(screen.display_name(true) == "pHmR Local Pilot","Local configuration uses the edited username")
	screen._leave()
	await settle()
	game.open_modal("leaderboard")
	await settle()
	input = field(game._hud)
	if input != null:
		check(input.text == "pHmR Local Pilot","Leaderboard mirrors the Multiplayer username")
		await type_name(input,"abcdefghijklmnopqrstuvwxyz")
		check(input.text == "abcdefghijklmnopqrst","Long usernames stop at 20 characters")
		verify_saved("abcdefghijklmnopqrst","Maximum-length username")
		await type_name(input,"蘑菇探险家小队你好世界测试名字保存二十字以上")
		var expected := "蘑菇探险家小队你好世界测试名字保存二十字以上".left(20)
		check(input.text == expected and input.text.length() == 20,"CJK names use the 20-character limit without truncating encoded characters")
		verify_saved(expected,"CJK username")
		await type_name(input,"   ")
		check(input.text.is_empty() and not input.placeholder_text.is_empty(),"Blank names restore the localized placeholder")
		verify_saved("","Blank username")
		await type_name(input,"Mushroom Captain",false)
		key(KEY_ESCAPE)
		await settle()
		check(game.routes.modal() == "leaderboard" and not input.has_focus(),"Escape leaves username editing without closing Leaderboard")
		verify_saved("Mushroom Captain","Leaving username editing with Escape")
	game.close_modal()
	check(game.start_stage(0),"Solo game starts with the shared username")
	game.session.score.total = 4321
	game.session.finish("defeat","timeout")
	game._finish_run()
	check(game.leaderboard.rows.size() == 1 and game.leaderboard.rows[0].name == "Mushroom Captain","A newly finished solo result records the saved username")
	var restored_board := Board.new()
	restored_board.path = game.leaderboard.path
	restored_board.load_data()
	check(restored_board.rows.size() == 1 and restored_board.rows[0].name == "Mushroom Captain","Leaderboard attribution survives a disk reload")
	game.return_title()
	await settle()
	for language in ["en","zh_CN"]:
		for profile in [[Vector2i(800,600),false],[Vector2i(1440,900),false],[Vector2i(320,568),true],[Vector2i(390,844),true]]:
			var view: Vector2i = profile[0]
			var mobile: bool = profile[1]
			await layout(view,mobile,language)
			var suffix := "%s-%dx%d" % [language,view.x,view.y]
			game.open_modal("leaderboard")
			await settle()
			verify_field(game._hud,"Leaderboard "+suffix)
			await shot("leaderboard-"+suffix)
			await verify_keyboard_resize(game._hud,view,mobile,"Leaderboard "+suffix)
			game.close_modal()
			if mobile:
				game.open_multiplayer()
				check(not game.multiplayer_active(),"Shared-keyboard multiplayer stays unavailable on mobile: "+suffix)
			else:
				game.open_multiplayer()
				await settle()
				screen = game._multiplayer_screen
				verify_field(screen,"Local multiplayer "+suffix)
				await shot("local-configuration-"+suffix)
				screen._start_local()
				await settle()
				check(screen.controls.local_label.text == "Mushroom Captain" and screen.controls.opponent_label.text == game.t("mp.player_two"),"Local cabinets display saved Player 1 and localized Player 2: "+suffix)
				screen._leave()
				await settle()
	await layout(Vector2i(1440,900),false)
	game.open_multiplayer()
	await settle()
	screen = game._multiplayer_screen
	screen._start_local()
	await settle()
	check(screen.local_match.player_name == "Mushroom Captain" and screen.controls.local_label.text == "Mushroom Captain","Local splitscreen uses the same saved username for player one")
	screen._leave()
	await settle()
	await finish()

func finish() -> void:
	game.queue_free()
	await settle(8)
	canvas.queue_free()
	await settle(4)
	await create_timer(0.25).timeout
	# Fixed-fps frames can outrun the native mixer; let queued music playback drain.
	OS.delay_msec(250)
	print("Username assertions: ",assertions,"; failures: ",failures.size())
	if failures.is_empty(): print("PASS: editable shared username, save reload, result attribution, multiplayer labels, keyboard input and responsive placement.")
	quit(0 if failures.is_empty() else 1)
