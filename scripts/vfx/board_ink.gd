extends Node2D
## 조준 가이드(세로 점선)와 데드라인. 데드라인을 넘은 공이 있으면 선이 빨갛게 깜빡입니다.
var game: Node
var _clock := 0.0

func _process(delta: float) -> void:
	_clock += delta

func guide_end_y(x: float, from_y: float) -> float:
	var end_y: float = game.tank_rect.end.y
	for toy in game.get_board_toys():
		if toy.held or toy.is_queued_for_deletion(): continue
		var dx: float = absf(toy.position.x - x)
		if dx >= toy.radius: continue
		var hit: float = toy.position.y - sqrt(toy.radius * toy.radius - dx * dx)
		if hit > from_y and hit < end_y: end_y = hit
	return end_y

func _draw() -> void:
	if not is_instance_valid(game): return
	var tank: Rect2 = game.tank_rect
	# Deadline.
	var line_y: float = game.danger_y()
	var warn: bool = game.danger_warning
	var color := Color(1.0, 0.52, 0.30, 0.95)
	var width := 4.0
	if warn:
		var blink := 0.5 + 0.5 * sin(_clock * 14.0)
		color = Color(0.93, 0.13, 0.16, 0.55 + 0.45 * blink)
		width = 6.0
		draw_rect(Rect2(tank.position.x, tank.position.y - 30, tank.size.x, line_y - tank.position.y + 30), Color(1, 0.15, 0.15, 0.10 * blink))
	draw_dashed_line(Vector2(tank.position.x + 6, line_y), Vector2(tank.end.x - 6, line_y), Color(0.12, 0.30, 0.40, 0.35), width + 3, 22, true)
	draw_dashed_line(Vector2(tank.position.x + 6, line_y), Vector2(tank.end.x - 6, line_y), color, width, 22, true)
	# Aim guide under the held ball.
	var held = game.held_toy
	if is_instance_valid(held) and not game.is_frozen():
		var x: float = game.aim_x
		var start_y: float = held.position.y + held.radius + 6
		var end_y := guide_end_y(x, start_y)
		draw_dashed_line(Vector2(x, start_y), Vector2(x, end_y), Color(1, 1, 1, 0.8), 3, 14, true)
		draw_circle(Vector2(x, end_y), 5, Color(1, 1, 1, 0.8))
