extends Control
## Ambient title life drawn in code: a warm breathing glow in the claw-machine glass,
## twinkling sparkles (additive) or softly rising felt hearts (normal blend).
## Counts stay small for Web/WASM; reduced motion freezes everything in a calm pose.

var mode := "sparkle" ## "sparkle" or "hearts"
var area := Rect2() ## Screen-space region the effect lives in.
var unit := 1.0
var reduced := false
var _time := 0.0
var _items: Array[Dictionary] = []
static var _glow_texture: GradientTexture2D

const HEART_COLORS := [Color("f59ab4"),Color("d7bdf0"),Color("fff4f7"),Color("ffc9a6"),Color("f7b8cc")]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if mode == "sparkle":
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
	var random := RandomNumberGenerator.new()
	random.seed = 5297 if mode == "sparkle" else 1811
	for index in range(16 if mode == "sparkle" else 9):
		_items.append({"x":random.randf(),"y":random.randf(),"size":random.randf_range(0.6,1.25),"speed":random.randf_range(0.8,1.9),
			"phase":random.randf()*TAU,"sway":random.randf_range(0.6,1.4),"color":HEART_COLORS[index%HEART_COLORS.size()]})
	set_process(not reduced)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

static func glow_texture() -> GradientTexture2D:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0,Color(1.0,0.86,0.58,0.9))
		gradient.set_color(1,Color(1.0,0.72,0.62,0.0))
		gradient.add_point(0.45,Color(1.0,0.8,0.62,0.35))
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5,0.5)
		_glow_texture.fill_to = Vector2(1.0,0.5)
		_glow_texture.width = 128
		_glow_texture.height = 128
	return _glow_texture

static func heart_points(center: Vector2,size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(28):
		var t := TAU*step/28.0
		var x := 16.0*pow(sin(t),3)
		var y := -(13.0*cos(t)-5.0*cos(2*t)-2.0*cos(3*t)-cos(4*t))
		points.append(center+Vector2(x,y+2.0)*(size/34.0))
	return points

static func draw_heart(canvas: CanvasItem,center: Vector2,size: float,color: Color,edge := Color(0,0,0,0),edge_width := 2.0) -> void:
	var points := heart_points(center,size)
	canvas.draw_colored_polygon(points,color)
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed,edge if edge.a > 0.0 else color,edge_width if edge.a > 0.0 else 1.0,true)

static func draw_sparkle(canvas: CanvasItem,center: Vector2,size: float,color: Color) -> void:
	if size < 0.5: return
	var points := PackedVector2Array()
	for step in range(8):
		var angle := PI*0.25*step-PI*0.5
		points.append(center+Vector2(cos(angle),sin(angle))*(size if step%2 == 0 else size*0.26))
	canvas.draw_colored_polygon(points,color)
	canvas.draw_circle(center,size*0.22,Color(1,1,1,color.a),true,-1.0,true)

func _draw() -> void:
	if not area.has_area(): return
	if mode == "sparkle":
		var pulse := 0.5 if reduced else 0.5+0.5*sin(_time*1.4)
		draw_texture_rect(glow_texture(),area.grow(area.size.x*0.12),false,Color(1,1,1,0.20+0.12*pulse))
		for item in _items:
			var at := area.position+Vector2(item.x,item.y)*area.size
			var twinkle: float = 0.55 if reduced else pow(maxf(0.0,sin(_time*float(item.speed)+float(item.phase))),3)
			draw_sparkle(self,at,11.0*unit*item.size*twinkle,Color(1.0,0.93,0.78,0.85*twinkle))
	else:
		var travel := area.size.y+40.0*unit
		for item in _items:
			var rise: float = 0.35 if reduced else fmod(float(item.y)+_time*float(item.speed)*0.035,1.0)
			var y := area.end.y+20.0*unit-rise*travel
			var x: float = area.position.x+float(item.x)*area.size.x+(0.0 if reduced else sin(_time*float(item.sway)+float(item.phase))*12.0*unit)
			var fade := clampf(minf(rise,1.0-rise)*5.0,0.0,1.0)
			var color: Color = item.color
			draw_heart(self,Vector2(x,y),15.0*unit*item.size,Color(color,0.62*fade),Color(1,1,1,0.55*fade),1.5)
