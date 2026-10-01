extends SceneTree
var game: Node
var canvas: SubViewport
var destination := ""
var assertions := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool,message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for unused in range(8): await process_frame

func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		destination = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(destination)
	canvas = SubViewport.new()
	canvas.size = Vector2i(390,844)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://scenes/main.tscn").instantiate()
	var settings_path := "user://title-language-"+str(Time.get_ticks_usec())+".json"
	game.settings.path = settings_path
	game.tweaks.enabled = false
	canvas.add_child(game)
	await settle()
	game.audio.set_muted(true)
	for size in [Vector2i(320,568),Vector2i(487,794),Vector2i(800,600),Vector2i(1440,900)]:
		canvas.size = size
		game.device.force_mobile = 1 if size.x < size.y else 0
		game._viewport_changed()
		game.return_title()
		await settle()
		for locale in ["en","zh_CN","en"]:
			var select: OptionButton = game._hud.base.find_children("*","OptionButton",true,false)[0]
			select.item_selected.emit(1 if locale == "zh_CN" else 0)
			await settle()
			select = game._hud.base.find_children("*","OptionButton",true,false)[0]
			var label: Label = select.get_parent().get_child(0)
			check(game.locale.locale == locale,"Language selection continues to update the game")
			check(label.text == game.t("ui.language"),"Title language label remains localized")
			check(label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,"Language label is centered horizontally and vertically")
			check(select.alignment == HORIZONTAL_ALIGNMENT_CENTER,"Selected language is centered")
			var arrow_space: float = select.get_theme_icon("arrow").get_width()+maxi(0,select.get_theme_constant("h_separation"))
			for state in ["normal","hover","pressed","focus","disabled"]:
				var box: StyleBox = select.get_theme_stylebox(state)
				check(is_equal_approx(box.get_margin(SIDE_LEFT),box.get_margin(SIDE_RIGHT)+arrow_space),"Text stays centered against the full dropdown in "+state)
			check(select.text == game.t("ui.chinese" if locale == "zh_CN" else "ui.english"),"Selected option remains correct")
			for control in [label,select]:
				check(Rect2(Vector2.ZERO,Vector2(size)).encloses(control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)),"Language control remains in the title viewport")
			game._hud._prepare_language_popup(weakref(select))
			check(select.get_popup().item_count == 2,"Both dropdown choices remain available")
			if not destination.is_empty():
				RenderingServer.force_draw(false)
				var image := canvas.get_texture().get_image()
				check(image != null and not image.is_empty(),"Native title image is available")
				check(image.save_png(destination.path_join("title-%s-%dx%d.png" % [locale,size.x,size.y])) == OK,"Native title capture saves")
	game.queue_free()
	await settle()
	if FileAccess.file_exists(settings_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	await create_timer(0.5).timeout
	print("TITLE_LANGUAGE assertions=%d failures=%d" % [assertions,failures])
	quit(1 if failures else 0)
