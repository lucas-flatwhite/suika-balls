extends SceneTree
## Render the complete solo UI in both locales, including scroll endpoints.
## godot --path . --audio-driver Dummy --disable-vsync --fixed-fps 60 \
##   --script tests/capture_ui_padding.gd -- /absolute/evidence/directory
## Add --smoke for English at 800x600 and 390x844; --geometry-only skips PNGs.
## Panel metadata ui_safe_insets is Vector4(left, top, right, bottom) in local
## pixels, including the decorative frame and its required text clearance.
const SIZES := [Vector2i(800,600),Vector2i(1024,768),Vector2i(1440,900),Vector2i(320,568),Vector2i(390,844),Vector2i(768,1024)]
const REQUIRED_CLEARANCE := 8.0
const ROUNDING_TOLERANCE := 0.6
var game: Node
var canvas: SubViewport
var destination := ""
var failures: Array[String] = []
var inventory: Array[Dictionary] = []
var assertions := 0
var captures := 0
var metadata_checks := 0
var style_checks := 0
var geometry_only := false
var suffix := ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool,message: String) -> void:
	assertions += 1
	if condition: return
	if not failures.has(message):
		failures.append(message)
		push_error(message)

func close_modals() -> void:
	while not game.routes.stack.is_empty(): game.close_modal()

func settle() -> void:
	for frame in range(10): await process_frame

func visible_rect(control: Control) -> Rect2:
	var bounds := control.get_global_rect().intersection(Rect2(Vector2.ZERO,Vector2(canvas.size)))
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents:
			bounds = bounds.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return bounds

func inset_rect(control: Control,insets: Vector4) -> Rect2:
	var local := Rect2(Vector2(insets.x,insets.y),control.size-Vector2(insets.x+insets.z,insets.y+insets.w))
	return control.get_global_transform() * local

func inspect_text(control: Control,state: String,rows: Array[Dictionary]) -> void:
	if not control.is_visible_in_tree(): return
	var content := String(control.text)
	if content.is_empty(): return
	var visible := visible_rect(control)
	if not visible.has_area(): return
	var text_bounds := control.get_global_rect()
	var parent := control.get_parent()
	while parent != null and parent != game._hud:
		if parent is Control and parent.has_meta("ui_safe_insets"):
			var safe := inset_rect(parent,parent.get_meta("ui_safe_insets"))
			# Clipped menu descendants are intentionally outside the scrolling
			# window. Compare only the part that actually reaches the display.
			check(safe.grow(ROUNDING_TOLERANCE).encloses(visible),state+": text safe region: "+content.left(70))
			metadata_checks += 1
		parent = parent.get_parent()
	rows.append({"text":content,"node":String(control.get_path()),"rect":[text_bounds.position.x,text_bounds.position.y,text_bounds.size.x,text_bounds.size.y],"visible_rect":[visible.position.x,visible.position.y,visible.size.x,visible.size.y]})

func inspect_tree(node: Node,state: String,rows: Array[Dictionary]) -> void:
	if node is Control and node.is_visible_in_tree() and visible_rect(node).has_area():
		var transform: Transform2D = node.get_global_transform()
		var scale := Vector2(transform.x.length(),transform.y.length())
		if node is Button:
			for variant in ["normal","hover","pressed","focus","disabled"]:
				inspect_style(node.get_theme_stylebox(variant),scale,state+": "+String(node.name)+" "+variant)
		elif node is LineEdit:
			for variant in ["normal","focus"]:
				inspect_style(node.get_theme_stylebox(variant),scale,state+": "+String(node.name)+" "+variant)
		elif node is PanelContainer:
			inspect_style(node.get_theme_stylebox("panel"),scale,state+": "+String(node.name)+" panel")
	if node is Label or node is Button or node is LineEdit:
		inspect_text(node,state,rows)
	for child in node.get_children(): inspect_tree(child,state,rows)

func inspect_style(box: StyleBox,scale: Vector2,label: String) -> void:
	if not box is StyleBoxFlat: return
	var margins := [box.content_margin_left,box.content_margin_top,box.content_margin_right,box.content_margin_bottom]
	var borders := [box.border_width_left,box.border_width_top,box.border_width_right,box.border_width_bottom]
	for side in range(4):
		var pixels: float = (float(margins[side])-float(borders[side]))*(scale.x if side%2 == 0 else scale.y)
		check(pixels+0.001 >= REQUIRED_CLEARANCE,label+": side %d has %.2fpx inside frame" % [side,pixels])
		style_checks += 1

func capture_dropdown(select: OptionButton,state: String,expected_modal := "") -> void:
	var popup := select.get_popup()
	popup.popup()
	await settle()
	var origin := select.get_global_rect().position+Vector2(0,select.get_global_rect().size.y)
	popup.position = Vector2i(clampf(origin.x,0,maxf(0,canvas.size.x-popup.size.x)),clampf(origin.y,0,maxf(0,canvas.size.y-popup.size.y)))
	check(popup.is_embedded(),state+" popup embeds in capture viewport: "+suffix)
	check(popup.visible,state+" popup is visible: "+suffix)
	var popup_transform := popup.get_final_transform()
	var popup_scale := Vector2(popup_transform.x.length(),popup_transform.y.length())
	inspect_style(popup.get_theme_stylebox("panel"),popup_scale,state+" popup "+suffix)
	await shot(state,expected_modal)
	var items: Array[String] = []
	for index in popup.item_count: items.append(popup.get_item_text(index))
	inventory.back()["popup"] = {"items":items,"position":[popup.position.x,popup.position.y],"size":[popup.size.x,popup.size.y],"font_size":popup.get_theme_font_size("font_size"),"render_scale":[popup_scale.x,popup_scale.y]}
	popup.hide()
	await settle()

func shot(state: String,expected_modal := "") -> void:
	for frame in range(10):
		# Native focus events may pause an offscreen game while another
		# capture window gains focus. Keep the requested fixture authoritative.
		if expected_modal.is_empty() and game.routes.route == "gameplay": close_modals()
		await process_frame
	var label := state+"-"+suffix
	check(game.routes.modal() == expected_modal,label+": expected modal")
	var scope: Node = game._hud.modals.back() if not game._hud.modals.is_empty() else game._hud.base
	var rows: Array[Dictionary] = []
	inspect_tree(scope,label,rows)
	check(not rows.is_empty(),label+": visible text exists")
	if not geometry_only:
		RenderingServer.force_draw(false)
		var screenshot := canvas.get_texture().get_image()
		check(screenshot.get_size() == canvas.size,label+": exact screenshot dimensions")
		check(screenshot.save_png(destination+"/"+label+".png") == OK,label+": screenshot saved")
	inventory.append({"capture":label,"locale":game.locale.locale,"size":[canvas.size.x,canvas.size.y],"route":game.routes.route,"modal":game.routes.modal(),"text":rows})
	captures += 1
	print("UI_PADDING_CAPTURE ",label)

func scroll_to(node: Node,bottom: bool) -> void:
	for child in node.get_children():
		if child is ScrollContainer:
			child.scroll_vertical = int(child.get_v_scroll_bar().max_value) if bottom else 0
		scroll_to(child,bottom)

func scroll_middle(node: Node) -> void:
	for child in node.get_children():
		if child is ScrollContainer:
			var bar: VScrollBar = child.get_v_scroll_bar()
			child.scroll_vertical = int(maxf(0,bar.max_value-bar.page)*0.5)
		scroll_middle(child)

func capture_scroll(state: String,modal := "") -> void:
	await settle()
	var scope: Node = game._hud.modals.back() if not game._hud.modals.is_empty() else game._hud.base
	scroll_to(scope,false)
	await shot(state+"-top",modal)
	if state == "settings":
		scroll_middle(scope)
		await shot(state+"-middle",modal)
	scroll_to(scope,true)
	await shot(state+"-bottom",modal)

func modal(kind: String) -> void:
	close_modals()
	game.open_modal(kind)
	await capture_scroll(kind,kind)
	close_modals()

func seed_leaderboard() -> void:
	game.leaderboard.rows.clear()
	for rank in range(10):
		game.leaderboard.rows.append({"run_id":"padding-%d" % rank,"name":"WWWWWWWWWWWWWWWWWWWW" if game.locale.locale == "en" else "蘑菇小伙伴蘑菇小伙伴蘑菇小伙伴蘑菇小伙伴","score":10000000-rank*12345,"stage":game.Stages.STAGES[rank%game.Stages.STAGES.size()].id,"outcome":"defeat" if rank%2 else "victory","timestamp":rank,"duration":3599.0+rank,"config":"padding-fixture","eligible":rank%2 == 0})

func fixture(locale: String,resolution: Vector2i) -> void:
	canvas.size = resolution
	game.locale.locale = locale
	game.settings.values.locale = locale
	TranslationServer.set_locale(locale)
	game.device.force_mobile = 1 if resolution.x < 500 else 0
	game.device.safe_insets = Vector4(0,44,0,34) if resolution.x < 500 else Vector4.ZERO
	game.input_method = "touch" if resolution.x < resolution.y else "keyboard"
	suffix = "%s-%dx%d" % [locale,resolution.x,resolution.y]
	game.tweaks.reset_all()
	game.return_title()
	game._viewport_changed()
	await shot("title")
	await modal("help")
	var languages: Array = game._hud.base.find_children("*","OptionButton",true,false)
	check(not languages.is_empty(),"Title language selector exists: "+suffix)
	if not languages.is_empty(): await capture_dropdown(languages[0],"title-language-dropdown")
	game.start_stage(0)
	close_modals()
	game.set_physics_process(false)
	game.discovered.fill(true)
	for index in range(4):
		var toy = game._spawn(index,Vector2(480+index*125,game.tank_rect.end.y-70))
		toy.freeze = true
	await shot("gameplay")
	game.session.score.total = 10000000
	game.session.goals_reached = 123
	game.session.goal_tier = 10
	game.session.goal_quantity = 125
	game.session.drops = 999
	game.next_tier = 8
	await shot("large-values")
	if game.tweaks.enabled:
		game.tweaks.request("ui.text.scale",1.2)
		await shot("large-values-text-120")
		game.tweaks.request("ui.text.scale",1.0)
		await settle()
	game.start_stage(0)
	game.set_physics_process(false)
	close_modals()
	await modal("pause")
	if game.tweaks.enabled:
		game.tweaks.request("ui.text.scale",1.2)
		game.open_modal("pause")
		await capture_scroll("pause-text-120","pause")
		close_modals()
		game.tweaks.request("ui.text.scale",1.0)
	game.confirm_loss("restart")
	await capture_scroll("confirm","confirm")
	close_modals()
	game.settings.values.name = "WWWWWWWWWWWWWWWWWWWW" if locale == "en" else "蘑菇小伙伴蘑菇小伙伴蘑菇小伙伴蘑菇小伙伴"
	await modal("settings")
	await modal("collection")
	game.leaderboard.rows.clear()
	game.open_modal("leaderboard")
	await capture_scroll("leaderboard-empty","leaderboard")
	close_modals()
	seed_leaderboard()
	game.open_modal("leaderboard")
	await capture_scroll("leaderboard-populated","leaderboard")
	close_modals()
	game.session.finish("defeat","overflow")
	game._finish_run()
	game.leaderboard.saved = false
	game._hud.rebuild()
	await capture_scroll("debrief-save-failure")
	game.error_key = "error.assets"
	game.routes.go("error")
	await capture_scroll("error")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	destination = args[0] if not args.is_empty() else "res://build/ui-padding-captures"
	geometry_only = args.has("--geometry-only")
	DirAccess.make_dir_recursive_absolute(destination)
	AudioServer.set_bus_mute(0,true)
	canvas = SubViewport.new()
	canvas.gui_embed_subwindows = true
	root.gui_embed_subwindows = true
	canvas.size = SIZES[0]
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://scenes/main.tscn").instantiate()
	canvas.add_child(game)
	await process_frame
	game.settings.path = "user://ui-padding-capture-settings.json"
	game.leaderboard.path = "user://ui-padding-capture-leaderboard.json"
	game.audio.set_muted(true)
	game.settings.values.muted = true
	var sizes: Array = [Vector2i(800,600),Vector2i(390,844)] if args.has("--smoke") else SIZES
	var locales: Array = ["en"] if args.has("--smoke") else ["en","zh_CN"]
	for locale in locales:
		for resolution in sizes:
			await fixture(locale,resolution)
	check(metadata_checks > 0,"Framed panels expose ui_safe_insets for geometric verification")
	var report := FileAccess.open(destination+"/ui-padding-report.json",FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"required_clearance_px":REQUIRED_CLEARANCE,"captures":captures,"assertions":assertions,"metadata_checks":metadata_checks,"style_checks":style_checks,"failures":failures,"inventory":inventory},"\t"))
	else: check(false,"UI padding report writes")
	game.queue_free()
	for frame in range(8): await process_frame
	canvas.queue_free()
	for frame in range(4): await process_frame
	# AudioStreamOggVorbis playback owners drain on the real audio clock;
	# fixed-fps simulation frames alone do not advance that cleanup clock.
	OS.delay_msec(250)
	print("UI_PADDING_CAPTURES ",captures," ASSERTIONS ",assertions," METADATA_CHECKS ",metadata_checks," STYLE_CHECKS ",style_checks," FAILURES ",failures.size())
	quit(0 if failures.is_empty() else 1)
