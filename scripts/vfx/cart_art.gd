extends RefCounted
## 해변 테마 공 수납함(볼 카트). 모두 코드로 그립니다. 좌표는 월드 단위.

static func _box(ci: CanvasItem, rect: Rect2, color: Color, radius := 12, border := Color.TRANSPARENT, width := 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	style.anti_aliasing = true
	ci.draw_style_box(style, rect)

static func draw_cart(ci: CanvasItem, tank: Rect2) -> void:
	var post_w := 26.0
	var left := tank.position.x - post_w
	var right := tank.end.x
	var top := tank.position.y - 34.0
	var floor_y := tank.end.y
	# Ground shadow on the sand.
	var shadow := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		shadow.append(Vector2(tank.get_center().x + cos(angle) * (tank.size.x * 0.62), floor_y + 68 + sin(angle) * 20))
	ci.draw_colored_polygon(shadow, Color(0.35, 0.22, 0.08, 0.20))
	# Back panel: airy sea-glass with a wire mesh.
	_box(ci, Rect2(tank.position - Vector2(2, 30), tank.size + Vector2(4, 30)), Color(0.88, 0.97, 1.0, 0.80), 10)
	var mesh := Color(0.32, 0.62, 0.70, 0.20)
	var x := tank.position.x + 50.0
	while x < tank.end.x - 10:
		ci.draw_line(Vector2(x, tank.position.y - 24), Vector2(x, floor_y), mesh, 2.0, true)
		x += 50.0
	var y := tank.position.y + 26.0
	while y < floor_y:
		ci.draw_line(Vector2(tank.position.x, y), Vector2(tank.end.x, y), mesh, 2.0, true)
		y += 52.0
	# Soft light gradient on the glass.
	ci.draw_rect(Rect2(tank.position.x + 14, tank.position.y - 20, 18, tank.size.y + 10), Color(1, 1, 1, 0.22))
	# Side posts (painted lifeguard teal) with caps.
	for post_x in [left, right]:
		_box(ci, Rect2(post_x, top, post_w, floor_y - top + 20), Color("1f9fb3"), 12, Color("137786"), 3)
		ci.draw_rect(Rect2(post_x + 6, top + 14, 6, floor_y - top - 10), Color(1, 1, 1, 0.30))
		ci.draw_circle(Vector2(post_x + post_w * 0.5, top), 18, Color("ffd23f"))
		ci.draw_arc(Vector2(post_x + post_w * 0.5, top), 18, 0, TAU, 32, Color("d99a12"), 3, true)
		ci.draw_circle(Vector2(post_x + post_w * 0.5 - 5, top - 5), 5, Color(1, 1, 1, 0.7))
	# Push handle on the right post.
	var handle := PackedVector2Array([Vector2(right + post_w, top + 70), Vector2(right + post_w + 18, top + 40), Vector2(right + post_w + 18, top - 6)])
	ci.draw_polyline(handle, Color("137786"), 12, true)
	ci.draw_polyline(handle, Color("3cc1d3"), 6, true)
	# Base tray with red-white lifeguard stripes.
	var tray := Rect2(left - 10, floor_y - 2, tank.size.x + post_w * 2 + 20, 44)
	_box(ci, tray, Color("ffffff"), 14, Color("c9353f"), 4)
	var stripe := tray.position.x + 22
	var stripe_index := 0
	while stripe < tray.end.x - 22:
		if stripe_index % 2 == 0:
			var quad := PackedVector2Array([Vector2(stripe, tray.position.y + 4), Vector2(stripe + 34, tray.position.y + 4), Vector2(stripe + 22, tray.end.y - 4), Vector2(stripe - 12, tray.end.y - 4)])
			ci.draw_colored_polygon(quad, Color("ef3e4a"))
		stripe += 34
		stripe_index += 1
	ci.draw_line(Vector2(tray.position.x + 12, tray.position.y + 6), Vector2(tray.end.x - 12, tray.position.y + 6), Color(1, 1, 1, 0.55), 3, true)
	# Wheels.
	for wheel_x in [tank.position.x + 50, tank.end.x - 50]:
		var hub := Vector2(wheel_x, floor_y + 62)
		ci.draw_circle(hub, 26, Color("2b2f36"))
		ci.draw_circle(hub, 15, Color("d6dde2"))
		ci.draw_circle(hub, 6, Color("8a959e"))
		ci.draw_arc(hub, 22, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.25), 3, true)
