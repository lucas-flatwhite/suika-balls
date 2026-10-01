extends SceneTree
## 로더 화면용 비치볼 이미지와 파비콘을 코드 드로잉으로 렌더링해 assets/ui/loader-ball.webp로 저장합니다.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var icon = load("res://scripts/ui/ball_icon.gd").new()
	icon.tier = 9
	icon.spin = -0.35
	icon.size = Vector2(256, 256)
	viewport.add_child(icon)
	for index in range(6): await process_frame
	var image := viewport.get_texture().get_image()
	image.save_webp("res://assets/ui/loader-ball.webp", true)
	# 파비콘: 같은 비치볼을 512px PNG로 (게임 전용 아이콘)
	viewport.size = Vector2i(512, 512)
	icon.size = Vector2(512, 512)
	for index in range(6): await process_frame
	viewport.get_texture().get_image().save_png("res://assets/share/favicon.png")
	print("saved loader ball")
	quit(0)
