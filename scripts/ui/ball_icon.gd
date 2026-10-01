extends Control
## 작은 공 아이콘(다음 공 미리보기, 진화 순서 줄, 결과 화면).
const BallArt := preload("res://scripts/ball_art.gd")
var tier := 0:
	set(value):
		tier = value
		queue_redraw()
var dim := false:
	set(value):
		dim = value
		queue_redraw()
var spin := 0.0
var highlight := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if highlight > 0.0:
		highlight = maxf(0.0, highlight - delta)
		queue_redraw()

func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 * 0.92
	var center := size * 0.5
	if highlight > 0.0:
		draw_circle(center, r * (1.25 + 0.2 * sin(highlight * 12.0)), Color(1, 0.95, 0.5, 0.55 * highlight))
	BallArt.draw_ball(self, tier, center, r, spin, 0.28 if dim else 1.0, r > 14.0)
