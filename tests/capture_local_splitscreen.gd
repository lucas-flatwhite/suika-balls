extends SceneTree
## Native graphical capture: godot --path . --audio-driver Dummy --script
## tests/capture_local_splitscreen.gd -- res://build/local-splitscreen-captures
var game: Node
var screen: Control
var canvas: SubViewport
var destination := ""
var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		push_error(message)

func wait_for(predicate: Callable, seconds := 8.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await process_frame
	check(false, "Timed out waiting for local splitscreen UI state")
	return false

func shot(label: String) -> void:
	for frame in range(8): await process_frame
	RenderingServer.force_draw(false)
	var output := canvas.get_texture().get_image()
	check(output.get_size() == canvas.size, "Capture has the requested dimensions: " + label)
	check(output.save_png(destination + "/local-" + label + ".png") == OK, "Capture saves: " + label)
	assert_text_clearance(label)
	print("CAPTURE local-", label)

func assert_text_clearance(label: String) -> void:
	if screen.controls.has("title"):
		var heading: Control = screen.controls.title.get_parent()
		check(heading.size.y <= heading.get_combined_minimum_size().y+1,"Single-line match header uses its settled padded height: "+label)
	for node in screen.find_children("*", "Control", true, false):
		if not node.is_visible_in_tree(): continue
		if node is Button or node is LineEdit or (node is Label and node.has_theme_stylebox_override("normal")):
			var style_names := ["normal","focus","disabled"] if node is Button else (["normal","focus","read_only"] if node is LineEdit else ["normal"])
			for style_name in style_names:
				var box: StyleBox = node.get_theme_stylebox(style_name)
				if not box is StyleBoxFlat: continue
				for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
					check(box.get_content_margin(side)-box.get_border_width(side) >= 8.0,"Eight-pixel text clearance in %s %s side %d: %s" % [node.name,style_name,side,label])
		if not (node is Label or node is Button or node is LineEdit): continue
		# Check the visible part of scrolled text against every enclosing panel.
		# Scrolling may clip a long page, but cannot carry glyphs into its border.
		var visible_rect: Rect2 = node.get_global_rect()
		var ancestor: Node = node.get_parent()
		while ancestor != null:
			if ancestor is Control and ancestor.clip_contents:
				visible_rect = visible_rect.intersection(ancestor.get_global_rect())
			if ancestor is PanelContainer and visible_rect.has_area():
				var panel_box: StyleBoxFlat = ancestor.get_theme_stylebox("panel")
				var inner: Rect2 = ancestor.get_global_rect()
				inner.position += Vector2(panel_box.border_width_left+8,panel_box.border_width_top+8)
				inner.size -= Vector2(panel_box.border_width_left+panel_box.border_width_right+16,panel_box.border_width_top+panel_box.border_width_bottom+16)
				check(inner.encloses(visible_rect),"Text remains eight pixels inside panel border: %s %s" % [node.name,label])
			ancestor = ancestor.get_parent()
	for key in ["local_status","opponent_status"]:
		if not screen.controls.has(key) or not screen.controls[key].is_visible_in_tree(): continue
		var status: Label = screen.controls[key]
		var view: Control = status.get_parent()
		check(view.get_glass_rect().grow(-8).encloses(status.get_rect()),"Finished badge clears the cabinet glass and irregular trim: "+label)
		var box: StyleBox = status.get_theme_stylebox("normal")
		var font: Font = status.get_theme_font("font")
		var font_size: int = status.get_theme_font_size("font_size")
		var text_width := font.get_string_size(status.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		check(status.get_line_count() == 1 and font_size >= 14 and text_width <= status.size.x-box.get_margin(SIDE_LEFT)-box.get_margin(SIDE_RIGHT),"Finished text fits one readable line inside its padded badge: "+label)
	for view in [screen.local_board,screen.opponent_board]:
		if not is_instance_valid(view): continue
		var font: Font = view.font
		for digit in ["1","2","3","4","5"]:
			var extent := Vector2(font.get_string_size(digit,HORIZONTAL_ALIGNMENT_LEFT,-1,view.BOMB_BADGE_FONT_SIZE).x,font.get_height(view.BOMB_BADGE_FONT_SIZE))
			check(view.bomb_badge_radius(digit)-view.BOMB_BADGE_BORDER_WIDTH*0.5-extent.length()*0.5 >= 8.0,"Bomb badge clears every text corner in viewport pixels: "+label)

func shot_scrolled(label: String) -> void:
	await shot(label)
	var changed := false
	for scroll in screen.find_children("*","ScrollContainer",true,false):
		if scroll.is_visible_in_tree() and scroll.get_v_scroll_bar().max_value > scroll.size.y:
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			changed = true
	if changed: await shot(label+"-scrolled")

func physical_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drop(player_id: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE if player_id == 1 else KEY_K
	event.keycode = event.physical_keycode
	event.pressed = true
	screen._unhandled_input(event)

func fully_visible(control: Control) -> bool:
	if not control.is_visible_in_tree(): return false
	var rect := control.get_global_rect()
	if not Rect2(Vector2.ZERO, Vector2(canvas.size)).encloses(rect): return false
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().encloses(rect): return false
		ancestor = ancestor.get_parent()
	return true

func score_fits(control: Label) -> bool:
	var font: Font = control.get_theme_font("font")
	var font_size := control.get_theme_font_size("font_size")
	var width := font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return control.get_line_count() == 1 and width <= control.size.x

func visible_text(text: String) -> bool:
	for label in screen.find_children("*", "Label", true, false):
		if label.text == text and fully_visible(label): return true
	return false

func run() -> void:
	var args := OS.get_cmdline_user_args()
	destination = args[0] if not args.is_empty() else "res://build/local-splitscreen-captures"
	DirAccess.make_dir_recursive_absolute(destination)
	AudioServer.set_bus_mute(0, true)
	for locale in ["en", "zh_CN"]:
		for resolution in [Vector2i(800,600),Vector2i(1024,768),Vector2i(1440,900)]:
			await capture_fixture(locale, resolution)
	# Allow native audio playback references to drain after the last owner is freed.
	await create_timer(0.25).timeout
	OS.delay_msec(250)
	print("LOCAL_SPLITSCREEN_UI_ASSERTIONS ", assertions, " FAILURES ", failures.size())
	quit(0 if failures.is_empty() else 1)

func capture_fixture(locale: String, resolution: Vector2i) -> void:
	var label := "%s-%dx%d" % [locale, resolution.x, resolution.y]
	canvas = SubViewport.new()
	canvas.size = resolution
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://scenes/main.tscn").instantiate()
	canvas.add_child(game)
	await process_frame
	game.device.force_mobile = 0
	game.device.refresh(Vector2(resolution))
	game.settings.path = "user://local-capture-settings.json"
	game.leaderboard.path = "user://local-capture-board.json"
	game.settings.values.muted = true
	game.audio.set_muted(true)
	game.locale.locale = locale
	game.return_title()
	game.open_multiplayer()
	screen = game._multiplayer_screen
	check(is_instance_valid(screen), "Multiplayer screen initializes: " + label)
	if not is_instance_valid(screen):
		await cleanup()
		return
	check(screen.controls.has("mp.local_splitscreen"), "Multiplayer offers Local Splitscreen: " + label)
	await shot(label + "-menu")
	check(fully_visible(screen.controls["mp.local_splitscreen"]), "Local mode button fits without scrolling: " + label)
	screen.controls["mp.local_splitscreen"].pressed.emit()
	check(screen.entry_mode == "local" and screen.phase == "countdown", "Local button starts local countdown: " + label)
	check(not screen.state.connected, "Local mode remains offline: " + label)
	await shot(label + "-countdown")
	check(visible_text(game.t("mp.local_ready_one")) and visible_text(game.t("mp.local_ready_two")), "Countdown shows both players' instructions without scrolling: " + label)
	if not await wait_for(func(): return screen.phase == "playing"):
		await cleanup()
		return
	check(screen.local_board.board.player_id == 1, "Player 1 is on the left: " + label)
	check(screen.opponent_board.board.player_id == 2, "Player 2 is on the right: " + label)
	check(screen.local_match.boards[0].get_world_2d() != screen.local_match.boards[1].get_world_2d(), "Boards have isolated physics: " + label)
	for drop_index in range(6):
		if not await wait_for(func(): return bool(screen.local_board.board.can_drop) and bool(screen.opponent_board.board.can_drop)):
			await cleanup()
			return
		screen.aim_x = 470 + float(drop_index % 3) * 100
		screen.opponent_aim_x = 800 + float(drop_index % 2) * 100
		for player_id in [1, 2]: drop(player_id)
		await create_timer(0.85).timeout
	await create_timer(0.8).timeout
	check(screen.local_board.board.drops == 6, "Space drops on Player 1's board: " + label)
	check(screen.opponent_board.board.drops == 6, "K drops on Player 2's board: " + label)
	check(screen.local_board.board.toys.size() > 0 and screen.opponent_board.board.toys.size() > 0, "Both boards display physical piles: " + label)
	check(screen.controls.has("next_texture") and screen.controls.has("opponent_next_texture"), "Both players have next-toy previews: " + label)
	check(not screen.controls.has("network"), "Local play omits network latency: " + label)
	await shot(label + "-playing")
	screen.controls["mp.audio"].grab_focus()
	await shot(label+"-keyboard-focus")
	screen.modal_kind = "audio"
	screen._build_overlay()
	await shot_scrolled(label + "-audio")
	screen.modal_kind = "leave"
	screen._build_overlay()
	await shot_scrolled(label+"-leave")
	screen.modal_kind = ""
	screen._build_overlay()
	canvas.size = Vector2i(600,800)
	for frame in range(8): await process_frame
	await shot_scrolled(label+"-portrait")
	canvas.size = resolution
	for frame in range(8): await process_frame
	var left: Node = screen.local_match.boards[0]
	var right: Node = screen.local_match.boards[1]
	# Capture a real, armed countdown at the small cabinet projection.
	var bomb: Node = left._spawn(11,Vector2(720,650))
	check(bomb.armed,"Capture uses a live armed Puff Bomb: "+label)
	await shot(label+"-bomb-countdown")
	left.session.score.total = 10000
	right.session.score.total = 10
	left.session.finish("defeat", "overflow")
	left._finish_run()
	if not await wait_for(func(): return screen.local_board.board.outcome == "defeat"):
		await cleanup()
		return
	check(screen.phase == "playing" and screen.state.winner_id == 0, "First defeat preserves active match and delays the winner: " + label)
	check(left.is_frozen() and not right.is_frozen(), "Only the defeated cabinet freezes: " + label)
	check(fully_visible(screen.controls.local_status) and screen.controls.local_status.text == game.t("mp.board_finished"), "Finished status fits inside the left cabinet without clipping: " + label)
	check(score_fits(screen.controls.local_score) and score_fits(screen.controls.opponent_score), "Both scores fit on one line with a five-digit leading score: " + label)
	check(not screen.controls.opponent_status.is_visible_in_tree(), "Surviving cabinet keeps its normal presentation: " + label)
	check(screen._can_control(false) and not screen._can_control(true), "Surviving player remains controllable without dismissing an overlay: " + label)
	var left_aim: float = left.aim_x
	var right_aim: float = right.aim_x
	var left_ui_aim: float = screen.aim_x
	var remaining: float = screen.state.remaining_seconds
	physical_key(KEY_A, true)
	physical_key(KEY_J, true)
	drop(1)
	drop(2)
	await create_timer(0.25).timeout
	physical_key(KEY_A, false)
	physical_key(KEY_J, false)
	await create_timer(0.7).timeout
	check(is_equal_approx(left.aim_x, left_aim) and is_equal_approx(screen.aim_x, left_ui_aim) and left.drop_count == 6, "Finished Player 1 ignores keyboard movement and release: " + label)
	check(right.aim_x < right_aim - 40 and right.drop_count == 7, "Player 2 can move and drop after Player 1 finishes: " + label)
	check(screen.phase == "playing" and float(screen.state.remaining_seconds) < remaining, "Shared timer keeps running after first defeat: " + label)
	await shot(label + "-first-defeat")
	# Shorten only this capture fixture's end time; exercise the real timeout path.
	screen.local_match._ends_at = screen.local_match._elapsed + 0.15
	if await wait_for(func(): return screen.phase == "finished"):
		check(screen.state.result_reason == "time" and screen.state.winner_id == 1, "Timeout compares scores and awards first-defeated Player 1 the win: " + label)
		await shot(label + "-results")
		var previous_epoch := int(screen.state.match_epoch)
		screen.controls.rematch.pressed.emit()
		check(screen.phase == "countdown" and screen.state.match_epoch == previous_epoch + 1, "Local rematch resets both players immediately: " + label)
	await cleanup()

func cleanup() -> void:
	if is_instance_valid(game): game.queue_free()
	for frame in range(6): await process_frame
	if is_instance_valid(canvas): canvas.queue_free()
	for frame in range(4): await process_frame
