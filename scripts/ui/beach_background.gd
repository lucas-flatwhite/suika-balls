extends Control
## 해변 배경(하늘·해·구름·바다·모래·파라솔·비치타월). 이미지 없이 코드로 그립니다.
## 화면 크기에 맞춰 늘어나고, 파도와 구름이 천천히 움직입니다.
var clock := 0.0
var animate := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not animate or not is_visible_in_tree(): return
	clock += delta
	if Engine.get_process_frames() % 3 == 0: queue_redraw()

func _gradient(rect: Rect2, top: Color, bottom: Color, steps := 24) -> void:
	for index in range(steps):
		var t0 := float(index) / steps
		draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * t0, rect.size.x, rect.size.y / steps + 1.0), top.lerp(bottom, t0))

func _ellipse(center: Vector2, radii: Vector2, color: Color, segments := 36) -> void:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / segments
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _cloud(center: Vector2, s: float) -> void:
	var c := Color(1, 1, 1, 0.92)
	_ellipse(center, Vector2(60, 22) * s, c)
	_ellipse(center + Vector2(-28, -14) * s, Vector2(30, 24) * s, c)
	_ellipse(center + Vector2(14, -22) * s, Vector2(36, 30) * s, c)

func _parasol(base: Vector2, s: float, a: Color, b: Color, tilt: float) -> void:
	var top := base + Vector2(sin(tilt), -cos(tilt)) * 150.0 * s
	draw_line(base, top, Color("8a6a4a"), maxf(2.0, 5.0 * s), true)
	var segments := 8
	var radius := 120.0 * s
	var dir := Vector2(cos(tilt), sin(tilt))
	var down := Vector2(-sin(tilt), cos(tilt))
	for index in range(segments):
		var t0 := -1.0 + 2.0 * float(index) / segments
		var t1 := -1.0 + 2.0 * float(index + 1) / segments
		var p0 := top + dir * radius * t0 + down * radius * 0.38 * (t0 * t0)
		var p1 := top + dir * radius * t1 + down * radius * 0.38 * (t1 * t1)
		var apex := top - down * radius * 0.28
		draw_colored_polygon(PackedVector2Array([apex, p0, p1]), a if index % 2 == 0 else b)
		# Scalloped edge.
		var mid := (p0 + p1) * 0.5 + down * radius * 0.06
		draw_colored_polygon(PackedVector2Array([p0, mid, p1]), (a if index % 2 == 0 else b).darkened(0.08))
	draw_circle(top - down * radius * 0.28, 5.0 * s, Color("ffd23f"))

func _draw() -> void:
	var view := size
	if view.x <= 0 or view.y <= 0: return
	var horizon := view.y * 0.50
	var shore := view.y * 0.64
	# Sky.
	_gradient(Rect2(0, 0, view.x, horizon), Color("5fc8f2"), Color("c9f1ff"))
	# Sun with soft halo.
	var sun := Vector2(view.x * 0.82, view.y * 0.13)
	for ring in range(4):
		draw_circle(sun, (70 + ring * 26) * clampf(view.y / 900.0, 0.6, 1.4), Color(1, 0.95, 0.6, 0.12))
	draw_circle(sun, 52 * clampf(view.y / 900.0, 0.6, 1.4), Color("fff3a8"))
	# Clouds drift slowly.
	var s := clampf(view.y / 900.0, 0.6, 1.5)
	for index in range(4):
		var x := fmod(view.x * (0.15 + index * 0.31) + clock * (8.0 + index * 3.0), view.x + 260.0) - 130.0
		_cloud(Vector2(x, view.y * (0.10 + 0.07 * (index % 2))), s * (0.8 + 0.25 * (index % 3)))
	# Sea.
	_gradient(Rect2(0, horizon, view.x, shore - horizon), Color("1f9fd0"), Color("4fd1e0"), 12)
	for row in range(5):
		var y := horizon + (shore - horizon) * (0.15 + row * 0.18)
		var points := PackedVector2Array()
		var step := 24.0
		var x := 0.0
		while x <= view.x + step:
			points.append(Vector2(x, y + sin(x * 0.03 + clock * (0.8 + row * 0.2) + row) * 3.0))
			x += step
		draw_polyline(points, Color(1, 1, 1, 0.22 + row * 0.04), 2.0, true)
	# Foam line and wet sand.
	var foam := PackedVector2Array()
	var fx := 0.0
	while fx <= view.x + 20.0:
		foam.append(Vector2(fx, shore + sin(fx * 0.02 + clock * 1.2) * 6.0))
		fx += 20.0
	var wet := foam.duplicate()
	wet.append(Vector2(view.x, view.y))
	wet.append(Vector2(0, view.y))
	draw_colored_polygon(wet, Color("f3d9a0"))
	_gradient(Rect2(0, shore + 24, view.x, view.y - shore), Color("f7e2ab"), Color("f0cf8c"), 12)
	draw_polyline(foam, Color(1, 1, 1, 0.85), 6.0, true)
	# Sand speckles.
	for index in range(60):
		var p := Vector2(fmod(index * 137.0, view.x), shore + 30 + fmod(index * 89.0, maxf(1.0, view.y - shore - 30)))
		draw_circle(p, 1.6, Color(0.75, 0.6, 0.38, 0.35))
	# Parasols and towels on both sides of the play column.
	var ps := clampf(view.y / 900.0, 0.55, 1.4)
	_parasol(Vector2(view.x * 0.10, view.y * 0.86), ps, Color("ef3e4a"), Color("ffffff"), -0.18)
	_parasol(Vector2(view.x * 0.90, view.y * 0.80), ps * 0.9, Color("2f7fe0"), Color("ffd23f"), 0.16)
	var towel := Rect2(view.x * 0.03, view.y * 0.90, 120 * ps, 54 * ps)
	draw_rect(towel, Color("2fbf71"))
	for stripe in range(3):
		draw_rect(Rect2(towel.position.x, towel.position.y + towel.size.y * (0.2 + stripe * 0.28), towel.size.x, towel.size.y * 0.1), Color(1, 1, 1, 0.8))
	# Starfish and shells.
	for spot in [Vector2(0.80, 0.94), Vector2(0.22, 0.74), Vector2(0.95, 0.70)]:
		var center := Vector2(view.x * spot.x, view.y * spot.y)
		for arm in range(5):
			var angle := TAU * arm / 5.0 - PI * 0.5
			draw_line(center, center + Vector2(cos(angle), sin(angle)) * 14 * ps, Color("ff8a5c"), 6 * ps, true)
		draw_circle(center, 5 * ps, Color("ff8a5c"))
