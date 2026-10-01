extends SceneTree
var game: Node
var canvas: SubViewport
var destination := ""
var assertions := 0
var failures: Array[String] = []
var captures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	assertions += 1
	if not value: failures.append(message); push_error(message)
func settle() -> void:
	for frame in range(16):
		while not game.routes.stack.is_empty(): game.close_modal()
		await process_frame
func inspect(label: String,large_text := false) -> void:
	var hud: Control = game._hud
	var bounds := Rect2(Vector2.ZERO,Vector2(canvas.size))
	for role in hud._hud_cards:
		var card: Dictionary = hud._hud_cards[role]
		var panel: PanelContainer = card.frame
		check(bounds.grow(1).encloses(panel.get_global_rect()),label+" "+role+" stays on screen")
		check(panel.size.y-float(panel.get_meta("hud_content_height")) <= 2.0,label+" "+role+" has no surplus vertical reservation")
		var scroll: ScrollContainer = card.body.get_parent()
		if not large_text:
			check(scroll.get_v_scroll_bar().max_value <= scroll.get_v_scroll_bar().page+1,label+" "+role+" needs no hidden scroll for default HUD")
	if hud._hud_cards.has("top"):
		var upper: Rect2 = hud._hud_cards.top.frame.get_global_rect()
		var lower: Rect2 = hud._hud_cards.lower.frame.get_global_rect()
		check(upper.end.y < lower.position.y,label+" stacked cards leave cabinet space")
		check(upper.size.x <= 960.1 and lower.size.x <= 960.1,label+" cards have bounded readable width")
		check(hud._hud_board_rect.size.y >= (160.0 if large_text else canvas.size.y*0.49),label+" compact cabinet retains usable height; default text gets half the screen")
		check(game._hud.controls.has("ui.left") and game._hud.controls.has("ui.right") and game._hud.controls.has("ui.drop"),label+" compact controls preserved")
	if hud._hud_cards.has("stats"):
		var upper: Rect2 = hud._hud_cards.stats.frame.get_global_rect()
		var lower: Rect2 = hud._hud_cards.actions.frame.get_global_rect()
		check(absf(lower.position.y-upper.end.y-12) <= 1,label+" side cards stay grouped")
		check(upper.size.x <= 460.1,label+" sidebar width is bounded")
		check(not upper.intersects(game.board_screen_rect) and not lower.intersects(game.board_screen_rect),label+" cards do not overlap cabinet")
	if hud.mobile:
		check(not hud.controls.has("ui.left") and not hud.controls.has("ui.drop"),label+" mobile direct-touch controls preserved")
		var names_bottom := 0.0
		for metric_key in ["goal","next"]:
			var metric: Label = hud.metrics[metric_key]
			check(metric.get_line_count() <= 2 and metric.get_visible_line_count() == metric.get_line_count(),label+" full mobile toy names fit their two-line budget")
			var card: Control = metric.get_parent()
			while card != null and not card is PanelContainer: card = card.get_parent()
			check(card != null,label+" mobile names have a bounded card")
			if card != null: names_bottom = maxf(names_bottom,card.get_global_rect().end.y)
		# Reserve readable name lines, then stop the header after its cards.
		check(hud.mobile_header.end.y-names_bottom >= 0 and hud.mobile_header.end.y-names_bottom <= 9,label+" mobile header has only its bottom padding after the name cards")
		check(game.board_screen_rect.size.y >= canvas.size.y*0.49,label+" mobile cabinet retains at least half the viewport")
	var board: Rect2 = canvas.canvas_transform * game.cabinet_bounds()
	check(bounds.grow(1).encloses(board),label+" cabinet stays visible")
	check(is_equal_approx(canvas.canvas_transform.x.length(),canvas.canvas_transform.y.length()),label+" cabinet is not stretched")
	if not destination.is_empty():
		RenderingServer.force_draw(false)
		check(canvas.get_texture().get_image().save_png(destination+"/"+label+".png") == OK,label+" capture")
		captures += 1
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): destination=args[0]; DirAccess.make_dir_recursive_absolute(destination)
	canvas=SubViewport.new();canvas.size=Vector2i(974,804);canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(canvas)
	game=load("res://scenes/main.tscn").instantiate();canvas.add_child(game)
	await process_frame
	game.settings.path="user://responsive-hud-settings.json"
	game.leaderboard.path="user://responsive-hud-board.json"
	game.tweaks.path="user://responsive-hud-tweaks.json"
	game.tweaks.reset_all();game.tweaks.enabled=false;game.audio.set_muted(true);game.device.force_mobile=0
	var sizes := [Vector2i(320,568),Vector2i(390,844),Vector2i(768,1024),Vector2i(800,600),Vector2i(974,804),Vector2i(960,960),Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1948,1608),Vector2i(2560,1080),Vector2i(3440,1440)]
	for language in ["en","zh_CN"]:
		game.locale.locale=language;game.start_stage(0);game.session.score.total=7000;game.session.goal_tier=6;game.next_tier=5
		for size in sizes:
			game.return_title();canvas.size=size;game._viewport_changed();game.start_stage(0);game.session.score.total=7000;game.session.goal_tier=6;game.next_tier=5;await settle()
			check(game.routes.route=="gameplay" and game.session.outcome.is_empty(),"A fresh run uses each chosen screen size")
			inspect("hud-%s-%dx%d" % [language,size.x,size.y])
		# Wrap growth must update bounds without a rebuild or empty minimum-height reservation.
		game.return_title();canvas.size=Vector2i(974,804);game._viewport_changed();game.start_stage(0);await settle()
		game.session.score.total=123456789;game.session.goal_tier=10;game.session.goal_quantity=125;game.next_tier=8
		await settle();inspect("long-values-"+language)
		game.tweaks.enabled=true;game.tweaks.request("ui.text.scale",1.2);game._hud.rebuild();await settle()
		inspect("large-text-"+language,true)
		game.tweaks.reset_all();game.tweaks.enabled=false
	# Start fresh runs across the compact breakpoint without leaking callbacks or overlapping panels.
	for width in [1024,1038,1041,1100,1041,1038,1024]:
		game.return_title();canvas.size=Vector2i(width,800);game._viewport_changed();game.start_stage(0);await settle();inspect("breakpoint-%d" % width)
	game.queue_free();for frame in range(8): await process_frame
	canvas.queue_free();for frame in range(4): await process_frame
	await create_timer(0.25).timeout
	print("RESPONSIVE_HUD assertions=%d captures=%d failures=%d" % [assertions,captures,failures.size()])
	quit(0 if failures.is_empty() else 1)
