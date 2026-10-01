extends SceneTree
## Mobile sheets exercise real local routes, native scrolling and keyboard reflow.
var game: Node
var canvas: SubViewport
var assertions := 0
var failures: Array[String] = []
var destination := ""
var save_paths: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool,message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		push_error(message)

func settle(frames := 6) -> void:
	for unused in range(frames): await process_frame

func shot(label: String) -> void:
	if destination.is_empty(): return
	await settle()
	RenderingServer.force_draw(false)
	var rendered := canvas.get_texture().get_image()
	check(rendered != null and not rendered.is_empty(),"Native capture is available: "+label)
	if rendered != null and not rendered.is_empty():
		check(rendered.save_png(destination.path_join(label+".png")) == OK,"Saved native capture: "+label)

func edge_checks(label: String,actions: Array[String]) -> void:
	var count := 0
	for node in game.find_children("*","ScrollBar",true,false):
		if node.is_visible_in_tree():
			count += 1
			check(node.name == "MobileEdgeScrollbar",label+": no internal scrollbar")
			check(absf(node.get_global_rect().end.x-canvas.size.x)<1,label+": scrollbar is flush right")
	check(count <= 1,label+": at most one visible scrollbar")
	var surface: Control = game._hud.active_surface()
	for key in actions:
		var control: Control = game._hud.controls[key]
		check(Rect2(Vector2.ZERO,canvas.size).grow(1).encloses(control.get_global_rect()),label+": fixed action visible "+key)
		check(control.size.y >= 44,label+": usable touch target "+key)
		check(surface.is_ancestor_of(control),label+": action belongs to active surface")

func exercise_scroll(scroll: ScrollContainer) -> void:
	scroll.scroll_vertical = 0
	var start := scroll.get_global_transform_with_canvas()*(scroll.size*0.65)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = start
	canvas.push_input(wheel,true)
	await settle()
	check(scroll.scroll_vertical > 0,"Wheel moves the single local standings body")
	scroll.scroll_vertical = 0
	Input.emulate_touch_from_mouse = true
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = start
	canvas.push_input(press,true)
	await process_frame
	for index in range(3):
		var drag := InputEventMouseMotion.new()
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		drag.relative = Vector2(0,-20)
		drag.position = start-Vector2(0,20*(index+1))
		canvas.push_input(drag,true)
		await process_frame
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = false
	press.position = start-Vector2(0,60)
	canvas.push_input(press,true)
	await settle()
	check(scroll.scroll_vertical > 0,"Native touch-emulated drag moves the local standings body")
	Input.emulate_touch_from_mouse = false

func finish_fixture() -> void:
	game.return_title()
	check(game.start_stage(0),"Local solo fixture starts")
	game.session.score.total = 10000000
	game.session.elapsed = 240
	game.session.finish("defeat","timeout")
	game._finish_run()
	game.leaderboard.rows.clear()
	for index in range(10):
		game.leaderboard.rows.append({"run_id":"mobile-fixture-"+str(index),"name":"Mushroom Captain","score":10000000-index,"duration":240,"outcome":"defeat","eligible":true,"stage":"first_hugs","timestamp":index,"config":"baseline"})

func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		destination = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(destination)
	canvas = SubViewport.new()
	canvas.size = Vector2i(390,844)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://scenes/main.tscn").instantiate()
	var prefix := "user://mobile-layout-"+str(Time.get_ticks_usec())
	for key in ["settings","leaderboard"]:
		var path: String = prefix+"-"+str(key)+".json"
		game.get(key).path = path
		save_paths.append(path)
	game.tweaks.enabled = false
	game.device.force_mobile = 1
	canvas.add_child(game)
	await settle()
	game.audio.set_muted(true)
	game.setting("name","Jun")
	for locale in ["en","zh_CN"]:
		game.locale.locale = locale
		for size in [Vector2i(320,568),Vector2i(390,844),Vector2i(430,932),Vector2i(320,240),Vector2i(390,320),Vector2i(430,400)]:
			canvas.size = size
			game.device.safe_insets = Vector4(0,12,8,8) if size.y >= 320 else Vector4.ZERO
			game._viewport_changed()
			finish_fixture()
			await settle()
			edge_checks("Results "+str(size),["ui.restart","ui.leaderboard","ui.title"])
			check(not canvas.gui_get_focus_owner() is LineEdit,"Results never open a keyboard")
			check(not game._hud.controls.has("global.publish"),"Local results contain no remote submission")
			await shot("results-"+locale+"-%dx%d" % [size.x,size.y])
			game.open_modal("leaderboard")
			await settle()
			edge_checks("Standings "+str(size),["ui.close"])
			check(not game._hud.base.visible,"Underlying results cannot show another scrollbar")
			check(not canvas.gui_get_focus_owner() is LineEdit,"Opening standings does not autofocus the name")
			var sheet: Control = game._hud.active_surface()
			var input: LineEdit = sheet.find_child("username_input",true,false)
			input.grab_focus()
			input.text = "Typed name"
			input.text_changed.emit(input.text)
			input.caret_column = 4
			await settle()
			if size.y >= 568:
				canvas.size = Vector2i(size.x,320)
				game._viewport_changed()
				await settle()
				input = game._hud.active_surface().find_child("username_input",true,false)
				check(input.has_focus() and input.caret_column == 4 and input.text == "Typed name","Keyboard resize retains active name and caret")
				check(game._hud.active_surface().scroll.get_global_rect().grow(1).encloses(input.get_global_rect()),"Keyboard resize reveals the active name above its navigation")
				await shot("keyboard-"+locale+"-%dx320" % size.x)
				canvas.size = size
				game._viewport_changed()
				await settle()
			game._hud.rebuild()
			game._hud.rebuild()
			await settle()
			sheet = game._hud.active_surface()
			input = sheet.find_child("username_input",true,false)
			check(input.has_focus() and input.caret_column == 4 and input.text == "Typed name","Reflow preserves the current editor and caret")
			check(sheet.scroll.get_global_rect().grow(1).encloses(input.get_global_rect()),"Current editor is visible above fixed navigation")
			game._hud.dismiss_editor()
			var scroll: ScrollContainer = sheet.scroll
			var width: float = scroll.get_child(0).size.x
			if scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page > 100:
				await exercise_scroll(scroll)
				scroll.scroll_vertical = 90
				await settle()
				check(is_equal_approx(width,scroll.get_child(0).size.x),"Edge scrollbar creates no content gutter")
				game._hud.rebuild()
				game._hud.rebuild()
				await settle()
				check(game._hud.active_surface().scroll.scroll_vertical == 90,"Repeated reflow preserves reading position")
			check(not canvas.gui_get_focus_owner() is LineEdit,"Reflow cannot resurrect a dismissed editor")
			await shot("standings-"+locale+"-%dx%d" % [size.x,size.y])
			game.close_modal()
			await settle()
			check(game._hud.find_child("ResultsScroll",true,false).scroll_vertical == 0,"Changing scrollbar ranges does not move the restored results")
			check(not canvas.gui_get_focus_owner() is LineEdit,"Closing standings leaves the keyboard dismissed")
			check(game._hud.base.visible,"Results return after dismissal")
	game.return_title()
	await settle()
	for route in ["help","collection","settings"]:
		game.open_modal(route)
		await settle()
		edge_checks(route,["ui.close"])
		await shot(route+"-mobile")
		if route == "settings":
			var editor: LineEdit = game._hud.active_surface().find_child("username_input",true,false)
			editor.grab_focus()
			editor.text = "Settings Captain"
			editor.text_changed.emit(editor.text)
			editor.caret_column = 3
			canvas.size = Vector2i(390,320)
			game._viewport_changed()
			await settle()
			editor = game._hud.active_surface().find_child("username_input",true,false)
			check(editor.has_focus() and editor.text == "Settings Captain" and editor.caret_column == 3,"Settings preserves its editor during keyboard resizing")
			game._hud.controls["ui.close"].pressed.emit()
			await settle()
			check(game.routes.modal().is_empty() and not canvas.gui_get_focus_owner() is LineEdit,"Settings Close dismisses both route and keyboard")
		else: game.close_modal()
		await settle()
	game.tweaks.enabled = true
	canvas.size = Vector2i(390,568)
	game._viewport_changed()
	finish_fixture()
	await settle()
	edge_checks("Owner results",["ui.restart","ui.leaderboard","ui.title"])
	check(game._hud.find_child("ui_tweaks",true,false) == null,"Native launcher is absent from results")
	game.start_stage(0)
	game.open_modal("pause")
	game.confirm_loss("restart")
	await settle()
	edge_checks("Owner confirmation",["ui.cancel","ui.confirm"])
	game.close_modal()
	game.close_modal()
	game.return_title()
	game.open_modal("help")
	await settle()
	check(not game._hud.controls.has("ui.replay"),"Owner help has no gameplay-starting action")
	await shot("owner-help-mobile")
	game.close_modal()
	game.tweaks.enabled = false
	game.return_title()
	game.device.force_mobile = 0
	canvas.size = Vector2i(1440,900)
	game._viewport_changed()
	game.open_modal("leaderboard")
	await settle()
	check(game.routes.modal() == "leaderboard","Desktop local standings opens after owner practice")
	check(not game.get_node("MobileScrollEdge").bar.visible,"Desktop restores native scrolling without the mobile edge")
	for scroll in game.find_children("*","ScrollContainer",true,false):
		check(not scroll.has_meta("edge_original_mode"),"Desktop restores each native scrollbar mode")
	game.close_modal()
	game.return_title()
	game.open_multiplayer()
	await settle()
	var screen: Control = game._multiplayer_screen
	screen._start_local()
	await settle()
	canvas.size = Vector2i(320,400)
	game._viewport_changed()
	await settle()
	check(is_instance_valid(screen.orientation_cover),"Rotated local match keeps its orientation notice")
	screen._request_leave()
	await settle()
	var edge = game.get_node("MobileScrollEdge")
	check(edge._scope() == screen.overlay,"Rotated Leave confirmation takes scroll priority over the covered orientation notice")
	check(is_instance_valid(edge.target) and screen.overlay.is_ancestor_of(edge.target),"Edge scrollbar controls the foreground Leave confirmation")
	screen._leave()
	await settle()
	game.queue_free()
	await settle()
	for path in save_paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await create_timer(0.5).timeout
	print("MOBILE_LAYOUT assertions=%d failures=%d" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
