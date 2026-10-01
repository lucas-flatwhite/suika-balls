extends Node2D
## 합체 파티클, "+점수" 팝업, 비치볼 축하 색종이. 모두 월드 좌표.
const MAX_PARTICLES := 220
const MAX_POPUPS := 16
var particles: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var reduced_motion := false
var intensity := 1.0
var ambient := true
var pulse := 0.0
var clock := 0.0
var paused := false
var font: Font
var bounds := Rect2(60,240,600,780)

func burst(at: Vector2, color := Color("ffd27a"), radius := 30.0) -> void:
	pulse = 0.5
	if reduced_motion: return
	var count := int((10 + radius * 0.12) * intensity)
	for index in range(count):
		if particles.size() >= MAX_PARTICLES: particles.pop_front()
		var angle := index * 2.399963 + randf() * 0.4
		var speed := 120.0 + randf() * 220.0 + radius
		var tint := color.lerp(Color.WHITE, randf() * 0.5)
		particles.append({"p":at + Vector2(cos(angle), sin(angle)) * radius * 0.6, "v":Vector2(cos(angle),sin(angle)) * speed,
			"life":0.55 + randf() * 0.3, "size":3.0 + randf() * 4.0 + radius * 0.03, "color":tint, "star": index % 3 == 0})

func celebrate(at: Vector2) -> void:
	pulse = 1.0
	if reduced_motion: return
	var palette := [Color("ef3e4a"), Color("ffffff"), Color("2f7fe0"), Color("ffc935"), Color("2fbf71"), Color("ff8fc8")]
	for index in range(int(90 * intensity)):
		if particles.size() >= MAX_PARTICLES: particles.pop_front()
		var angle := randf() * TAU
		var speed := 200.0 + randf() * 520.0
		particles.append({"p":at, "v":Vector2(cos(angle), sin(angle) - 0.6) * speed, "life":1.1 + randf() * 0.8,
			"size":5.0 + randf() * 6.0, "color":palette[index % palette.size()], "confetti":true, "spin":randf() * TAU})

func popup(at: Vector2, text: String, color := Color.WHITE, size := 34) -> void:
	if popups.size() >= MAX_POPUPS: popups.pop_front()
	popups.append({"p":at, "text":text, "color":color, "size":size, "life":0.9, "max":0.9})

func clear() -> void:
	particles.clear()
	popups.clear()
	pulse = 0
	clock = 0

func _process(delta: float) -> void:
	if paused: return
	clock += delta
	pulse = maxf(0, pulse - delta * 2)
	for particle in particles:
		particle.p += particle.v * delta
		if particle.get("confetti", false):
			particle.v *= 0.985
			particle.v.y += 260 * delta
			particle.spin += delta * 8.0
		else:
			particle.v *= 0.94
			particle.v.y += 160 * delta
		particle.life -= delta
	particles = particles.filter(func(p: Dictionary) -> bool: return p.life > 0)
	for item in popups:
		item.p.y -= 70.0 * delta
		item.life -= delta
	popups = popups.filter(func(p: Dictionary) -> bool: return p.life > 0)
	queue_redraw()

func _draw() -> void:
	for particle in particles:
		var alpha := clampf(particle.life * 1.6, 0.0, 1.0)
		var color: Color = particle.color
		color.a = alpha
		if particle.get("confetti", false):
			draw_set_transform(particle.p, particle.spin, Vector2.ONE)
			draw_rect(Rect2(-particle.size * 0.5, -particle.size * 0.3, particle.size, particle.size * 0.6), color)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif particle.get("star", false):
			var s: float = particle.size
			draw_line(particle.p - Vector2(s, 0), particle.p + Vector2(s, 0), color, 2.0, true)
			draw_line(particle.p - Vector2(0, s), particle.p + Vector2(0, s), color, 2.0, true)
		else:
			draw_circle(particle.p, particle.size * 0.5, color)
	if font != null:
		for item in popups:
			var fade := clampf(item.life / item.max * 1.6, 0.0, 1.0)
			var grow := 1.0 + (1.0 - clampf((item.max - item.life) / 0.15, 0.0, 1.0)) * 0.4
			var size := int(item.size * grow)
			var width := font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var at: Vector2 = item.p - Vector2(width * 0.5, 0)
			draw_string_outline(font, at, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 6), Color(0.15, 0.10, 0.25, 0.8 * fade))
			var c: Color = item.color
			c.a = fade
			draw_string(font, at, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	if pulse > 0:
		draw_rect(bounds.grow(-2), Color(1.0, 0.95, 0.6, pulse * 0.30), false, 6)
