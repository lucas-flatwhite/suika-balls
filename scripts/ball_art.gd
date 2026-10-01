extends RefCounted
## 이미지 파일 없이 10종 스포츠 공을 코드로 그립니다.
## draw_ball()은 공의 회전(rotation)을 받아 무늬를 함께 돌리고,
## 광택·그림자는 화면 기준으로 고정해 공이 구르는 것이 보이게 합니다.
const Balls := preload("res://data/balls.gd")

const OUTLINE := Color(0.18, 0.13, 0.10, 0.55)

static func circle_points(r: float, segments := 40, center := Vector2.ZERO) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points

static func _clip(ci: CanvasItem, polygon: PackedVector2Array, r: float, color: Color) -> void:
	var clipped := Geometry2D.intersect_polygons(polygon, circle_points(r * 0.995, 48))
	for piece in clipped:
		if piece.size() >= 3: ci.draw_colored_polygon(piece, color)

static func _curve_inside(ci: CanvasItem, points: PackedVector2Array, r: float, color: Color, width: float) -> void:
	# Draw only the parts of a polyline that stay inside the ball.
	var run := PackedVector2Array()
	for point in points:
		if point.length() <= r * 0.985:
			run.append(point)
		else:
			if run.size() >= 2: ci.draw_polyline(run, color, width, true)
			run = PackedVector2Array()
	if run.size() >= 2: ci.draw_polyline(run, color, width, true)

static func _arc_points(center: Vector2, radius: float, from: float, to: float, segments := 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var angle := lerpf(from, to, float(index) / float(segments))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

## ci: 그릴 CanvasItem, center/r: 화면(로컬) 좌표, rotation: 공 회전.
## scale: 팝(커짐) 연출용 비율, alpha: 진화 줄의 흐린 단계 등.
static func draw_ball(ci: CanvasItem, tier: int, center: Vector2, r: float, rotation := 0.0, alpha := 1.0, detail := true, light_rotation := 0.0) -> void:
	if r <= 0.5: return
	var colors: Array = Balls.ball(tier).colors
	# Soft contact shadow, fixed to the screen.
	ci.draw_set_transform(center, light_rotation, Vector2.ONE)
	ci.draw_circle(Vector2(r * 0.06, r * 0.10), r * 1.02, Color(0.12, 0.08, 0.05, 0.16 * alpha))
	# Rotating pattern layer.
	ci.draw_set_transform(center, rotation, Vector2.ONE)
	var base: Color = colors[0]
	base.a *= alpha
	ci.draw_circle(Vector2.ZERO, r, base)
	match tier:
		0: _pingpong(ci, r, alpha)
		1: _golf(ci, r, alpha, detail)
		2: _tennis(ci, r, alpha)
		3: _stitched(ci, r, alpha, colors[1], detail)
		4: _stitched(ci, r, alpha, colors[1], detail)
		5: _volleyball(ci, r, alpha, colors)
		6: _soccer(ci, r, alpha, colors[1])
		7: _basketball(ci, r, alpha, colors[1])
		8: _gymball(ci, r, alpha, colors)
		9: _beachball(ci, r, alpha, colors)
	# Fixed lighting: rim shade, highlight and outline do not rotate.
	ci.draw_set_transform(center, light_rotation, Vector2.ONE)
	ci.draw_arc(Vector2(r * 0.05, r * 0.07), r * 0.9, -0.2, PI * 0.95, 28, Color(0, 0, 0, 0.10 * alpha), r * 0.18, true)
	var gloss := 0.55 if tier != 8 else 0.85
	ci.draw_circle(Vector2(-r * 0.36, -r * 0.40), r * (0.20 if tier != 8 else 0.30), Color(1, 1, 1, gloss * 0.45 * alpha))
	ci.draw_circle(Vector2(-r * 0.42, -r * 0.46), r * (0.08 if tier != 8 else 0.13), Color(1, 1, 1, gloss * alpha))
	ci.draw_arc(Vector2.ZERO, r, 0, TAU, maxi(24, int(r * 0.9)), Color(OUTLINE, OUTLINE.a * alpha), clampf(r * 0.06, 1.2, 3.5), true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _pingpong(ci: CanvasItem, r: float, alpha: float) -> void:
	# Plain orange ball; a faint moulding seam lets the spin show.
	ci.draw_arc(Vector2.ZERO, r * 0.98, 0, TAU, 32, Color(1, 1, 1, 0.0), 1, true)
	ci.draw_line(Vector2(-r * 0.97, 0), Vector2(r * 0.97, 0), Color(1, 0.86, 0.68, 0.55 * alpha), maxf(1.0, r * 0.07), true)
	ci.draw_circle(Vector2(r * 0.42, r * 0.38), r * 0.09, Color(1, 0.95, 0.85, 0.65 * alpha))

static func _golf(ci: CanvasItem, r: float, alpha: float, detail: bool) -> void:
	var dimple := Color(0.70, 0.73, 0.75, 0.75 * alpha)
	var step := r * (0.30 if detail else 0.42)
	var dot := maxf(0.9, step * 0.24)
	var row := 0
	var y := -r
	while y <= r:
		var x := -r + (step * 0.5 if row % 2 == 1 else 0.0)
		while x <= r:
			var p := Vector2(x, y)
			if p.length() < r * 0.86: ci.draw_circle(p, dot, dimple)
			x += step
		y += step * 0.866
		row += 1

static func _tennis(ci: CanvasItem, r: float, alpha: float) -> void:
	var seam := Color(1, 1, 1, 0.95 * alpha)
	var width := maxf(1.4, r * 0.12)
	_curve_inside(ci, _arc_points(Vector2(-r * 1.32, 0), r * 0.98, -1.2, 1.2, 36), r, seam, width)
	_curve_inside(ci, _arc_points(Vector2(r * 1.32, 0), r * 0.98, PI - 1.2, PI + 1.2, 36), r, seam, width)
	# Felt fuzz flecks.
	for index in range(7):
		var angle := float(index) * 2.4
		ci.draw_circle(Vector2(cos(angle), sin(angle)) * r * 0.55, maxf(0.6, r * 0.035), Color(0.95, 1, 0.6, 0.5 * alpha))

static func _stitched(ci: CanvasItem, r: float, alpha: float, red: Color, detail: bool) -> void:
	var thread := Color(red, 0.95 * alpha)
	var width := maxf(1.0, r * 0.05)
	for side in [-1.0, 1.0]:
		var center := Vector2(side * r * 1.30, 0)
		var start := -1.05 if side < 0 else PI - 1.05
		var points := _arc_points(center, r * 0.95, start, start + 2.1, 30)
		_curve_inside(ci, points, r, Color(thread, thread.a * 0.6), width)
		if not detail: continue
		# Stitch ticks: little V marks across the seam.
		var count := 9
		for index in range(1, count):
			var a := start + 2.1 * float(index) / float(count)
			var p := center + Vector2(cos(a), sin(a)) * r * 0.95
			if p.length() > r * 0.9: continue
			var normal := Vector2(cos(a), sin(a))
			var tangent := Vector2(-normal.y, normal.x)
			var tick := r * 0.11
			ci.draw_line(p - normal * tick + tangent * tick * 0.5, p, thread, width, true)
			ci.draw_line(p + normal * tick + tangent * tick * 0.5, p, thread, width, true)

static func _spiral(r: float, base: float, sweep: float, segments := 18) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var angle := base + t * sweep
		points.append(Vector2(cos(angle), sin(angle)) * r * t * 1.02)
	return points

static func _volleyball(ci: CanvasItem, r: float, alpha: float, colors: Array) -> void:
	# Three curved panel groups; colors are generic teal/coral, not a brand scheme.
	var fills := [Color(colors[1], alpha), Color(colors[0], alpha), Color(colors[2], alpha)]
	var sweep := 1.1
	for k in range(3):
		var a0 := TAU * float(k) / 3.0
		var a1 := TAU * float(k + 1) / 3.0
		var polygon := _spiral(r, a0, sweep)
		var edge := _arc_points(Vector2.ZERO, r * 1.02, a0 + sweep, a1 + sweep, 16)
		polygon.append_array(edge)
		var back := _spiral(r, a1, sweep)
		back.reverse()
		polygon.append_array(back)
		_clip(ci, polygon, r, fills[k])
	var line := Color(0.25, 0.30, 0.35, 0.55 * alpha)
	var width := maxf(1.0, r * 0.04)
	for k in range(3):
		var a0 := TAU * float(k) / 3.0
		_curve_inside(ci, _spiral(r, a0, sweep), r, line, width)
		for offset in [0.33, 0.66]:
			var mid := _spiral(r, a0 + TAU / 3.0 * offset, sweep)
			_curve_inside(ci, mid, r, Color(line, line.a * 0.55), width * 0.8)

static func _pentagon(center: Vector2, size: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(5):
		var angle := rotation + TAU * float(index) / 5.0 - PI * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	return points

static func _soccer(ci: CanvasItem, r: float, alpha: float, black: Color) -> void:
	var ink := Color(black, alpha)
	var line := Color(black, 0.55 * alpha)
	var width := maxf(1.0, r * 0.035)
	var middle := _pentagon(Vector2.ZERO, r * 0.30, 0.0)
	ci.draw_colored_polygon(middle, ink)
	for index in range(5):
		var angle := TAU * float(index) / 5.0 - PI * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		var outer := _pentagon(direction * r * 0.86, r * 0.27, PI)
		_clip(ci, outer, r, ink)
		var inner_vertex: Vector2 = middle[index]
		ci.draw_line(inner_vertex, inner_vertex + direction * r * 0.30, line, width, true)
		var side := Vector2(cos(angle + TAU / 10.0), sin(angle + TAU / 10.0))
		_curve_inside(ci, PackedVector2Array([side * r * 0.55, side * r * 1.0]), r, line, width)

static func _basketball(ci: CanvasItem, r: float, alpha: float, black: Color) -> void:
	var seam := Color(black, 0.9 * alpha)
	var width := maxf(1.2, r * 0.05)
	ci.draw_line(Vector2(0, -r * 0.98), Vector2(0, r * 0.98), seam, width, true)
	ci.draw_line(Vector2(-r * 0.98, 0), Vector2(r * 0.98, 0), seam, width, true)
	_curve_inside(ci, _arc_points(Vector2(-r * 1.15, 0), r * 0.82, -1.25, 1.25, 30), r, seam, width)
	_curve_inside(ci, _arc_points(Vector2(r * 1.15, 0), r * 0.82, PI - 1.25, PI + 1.25, 30), r, seam, width)
	# Pebbled grain.
	for index in range(14):
		var angle := float(index) * 2.39996
		var distance := r * (0.25 + 0.6 * fmod(float(index) * 0.37, 1.0))
		ci.draw_circle(Vector2(cos(angle), sin(angle)) * distance, maxf(0.5, r * 0.025), Color(0.55, 0.25, 0.05, 0.25 * alpha))

static func _gymball(ci: CanvasItem, r: float, alpha: float, colors: Array) -> void:
	# Solid rubber with a moulding ring and a valve so rotation reads.
	ci.draw_arc(Vector2.ZERO, r * 0.72, 0.4, 2.2, 24, Color(1, 1, 1, 0.18 * alpha), maxf(1.0, r * 0.05), true)
	ci.draw_circle(Vector2(r * 0.58, r * 0.30), r * 0.06, Color(colors[1], 0.9 * alpha))
	ci.draw_circle(Vector2(r * 0.58, r * 0.30), r * 0.03, Color(0.35, 0.18, 0.55, 0.9 * alpha))

static func _beachball(ci: CanvasItem, r: float, alpha: float, colors: Array) -> void:
	# Six vertical gores between meridian curves, meeting at the poles.
	var order := [colors[0], colors[1], colors[2], colors[3], colors[1], colors[4]]
	var longitudes := []
	for index in range(7): longitudes.append(-PI * 0.5 + PI * float(index) / 6.0)
	for k in range(6):
		var polygon := PackedVector2Array()
		var segments := 20
		for step in range(segments + 1):
			var lat := lerpf(-PI * 0.5, PI * 0.5, float(step) / float(segments))
			polygon.append(Vector2(r * cos(lat) * sin(longitudes[k]), r * sin(lat)))
		for step in range(segments, -1, -1):
			var lat := lerpf(-PI * 0.5, PI * 0.5, float(step) / float(segments))
			polygon.append(Vector2(r * cos(lat) * sin(longitudes[k + 1]), r * sin(lat)))
		_clip(ci, polygon, r, Color(order[k], alpha))
	# White cap at the top pole and a small one at the bottom.
	_cap(ci, Vector2(0, -r * 0.80), r * 0.30, r * 0.20, alpha)
	_cap(ci, Vector2(0, r * 0.86), r * 0.20, r * 0.12, alpha * 0.9)

static func _cap(ci: CanvasItem, at: Vector2, w: float, h: float, alpha: float) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(at + Vector2(cos(angle) * w, sin(angle) * h))
	ci.draw_colored_polygon(points, Color(1, 1, 1, alpha))
	points.append(points[0])
	ci.draw_polyline(points, Color(0.6, 0.6, 0.65, 0.5 * alpha), maxf(1.0, w * 0.06), true)
