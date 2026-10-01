extends SceneTree
## Local results remain readable and actionable without scrolling at compact desktop sizes.
var game: Node
var canvas: SubViewport
var destination := ""
var assertions := 0
var failures := 0
var save_paths: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(value: bool,message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in range(8): await process_frame

func check_results_fit(context: String) -> void:
	var scroll := game._hud.find_child("ResultsScroll",true,false) as ScrollContainer
	check(scroll != null,"Local results have a content viewport: "+context)
	if scroll == null: return
	var body := scroll.get_child(0) as VBoxContainer
	check(body != null,"Local result content is present: "+context)
	if body == null: return
	check(not game._hud.mobile,"Desktop results retain desktop layout: "+context)
	check(not scroll.get_v_scroll_bar().is_visible_in_tree(),"Results have no scrollbar gutter: "+context)
	check(is_equal_approx(body.size.x,scroll.size.x),"Result content fills its viewport width: "+context)
	check(scroll.get_v_scroll_bar().max_value <= scroll.get_v_scroll_bar().page+1,"Results need no scrolling: %s content=%s viewport=%s" % [context,body.size,scroll.size])
	var view := Rect2(Vector2.ZERO,Vector2(canvas.size)).grow(1)
	check(view.encloses(scroll.get_global_rect()),"Result viewport stays on screen: "+context)
	for control in body.find_children("*","Control",true,false):
		if (control is Button or control is LineEdit or control is Label) and control.is_visible_in_tree():
			check(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"Result control is fully visible: "+context+" "+str(control.name))
	for key in ["ui.restart","ui.leaderboard","ui.title"]:
		var button: Button = game._hud.controls[key]
		check(view.encloses(button.get_global_rect()),"Result action remains on screen: "+context+" "+key)
	check(not game._hud.controls.has("global.publish") and game._hud.find_child("ResultSharing",true,false) == null,"Results retain local-only actions: "+context)
	var labels: Array[String] = []
	for label in body.find_children("*","Label",true,false): labels.append(label.text)
	check(labels.has(game.t("result.summary",{"score":10000000,"merges":9999,"seconds":9999})),"Large score and duration remain complete: "+context)
	check(labels.has(game.t("result.save_failed")) == (not game.is_sandbox_mode() and not game.leaderboard.saved),"Save-failure feedback is present only for the failed local save: "+context)
	check(labels.has(game.t("leaderboard.practice")) == game.is_sandbox_mode(),"Owner results retain the practice notice: "+context)

func finish_fixture() -> void:
	game.return_title()
	check(game.start_stage(0),"Local solo fixture starts")
	game.session.elapsed = 9999
	game.session.merges = 9999
	game.session.score.total = 10000000
	game.session.finish("defeat","timeout")
	game._finish_run()

func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		destination = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(destination)
	canvas = SubViewport.new()
	canvas.size = Vector2i(800,600)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://scenes/main.tscn").instantiate()
	var prefix := "user://local-results-fit-"+str(Time.get_ticks_usec())
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
		for size in [Vector2i(800,600),Vector2i(1024,600),Vector2i(1280,720),Vector2i(1920,1080)]:
			canvas.size = size
			game.device.force_mobile = 0
			game._viewport_changed()
			finish_fixture()
			await settle()
			for state in ["saved","save_failed","owner"]:
				game.leaderboard.saved = state != "save_failed"
				game.tweaks.enabled = state == "owner"
				if state == "owner": check(game.tweaks.request("ui.text.scale",1.2),"Maximum owner text scale is accepted")
				game._hud.rebuild()
				await settle()
				var context := "%s-%dx%d-%s" % [locale,size.x,size.y,state]
				check_results_fit(context)
				if not destination.is_empty() and size == Vector2i(800,600):
					RenderingServer.force_draw(false)
					var image := canvas.get_texture().get_image()
					check(image != null and not image.is_empty(),"Native result image is available: "+context)
					if image != null and not image.is_empty(): check(image.save_png(destination.path_join(context+".png")) == OK,"Native result capture saves: "+context)
				if state == "owner":
					game.tweaks.request("ui.text.scale",1.0)
					game.tweaks.enabled = false
	game.queue_free()
	await settle()
	for path in save_paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await create_timer(0.25).timeout
	print("PC_RESULTS_FIT assertions=%d failures=%d" % [assertions,failures])
	quit(1 if failures else 0)
