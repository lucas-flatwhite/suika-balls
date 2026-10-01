extends Control
## Claw-machine marquee topper behind the Mushies logo: a stitched lilac felt plaque
## ringed by warm bulbs that chase like an arcade sign (static when motion is reduced).

const PlushStyle := preload("res://scripts/ui/plush_style.gd")

var unit := 1.0
var reduced := false
var plaque: StyleBox
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not reduced)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO,size)
	if plaque != null: draw_style_box(plaque,rect)
	var inset := 13.0*unit
	var path := PlushStyle.outline(rect.grow(-inset),maxf(4.0,30.0*unit-inset),8)
	var total := 0.0
	for index in range(path.size()-1): total += path[index].distance_to(path[index+1])
	var count := clampi(int(total/maxf(30.0*unit,8.0)),12,200)
	var spacing := total/count
	var chase := int(_time*6.0)
	var walked := 0.0
	var next_at := spacing*0.5
	var bulb := 0
	for index in range(path.size()-1):
		var a := path[index]
		var b := path[index+1]
		var length := a.distance_to(b)
		while next_at <= walked+length and bulb < count:
			var at := a.lerp(b,(next_at-walked)/maxf(length,0.001))
			var lit := reduced or (bulb+chase)%3 != 0
			if lit:
				draw_circle(at,7.5*unit,Color(1.0,0.84,0.5,0.28),true,-1.0,true)
				draw_circle(at,4.4*unit,Color("fff1bf"),true,-1.0,true)
				draw_circle(at-Vector2(1.2,1.2)*unit,1.7*unit,Color(1,1,1,0.95),true,-1.0,true)
			else:
				draw_circle(at,4.2*unit,Color("efe0f6"),true,-1.0,true)
				draw_circle(at,4.2*unit,Color("b99bd4"),false,1.2*unit,true)
			bulb += 1
			next_at += spacing
		walked += length
