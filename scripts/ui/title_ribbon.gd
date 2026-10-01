extends Control
## Felt ribbon banner (notched tails + stitched edges) that carries the tagline.

const PlushStyle := preload("res://scripts/ui/plush_style.gd")

var unit := 1.0
var band := Color("f28fab")
var tail := Color("d86f8f")
var seam := Color(1,1,1,0.75)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	var drop := 8.0*unit
	var tail_w := 30.0*unit
	var notch := 11.0*unit
	for side: float in [-1.0,1.0]:
		var x0: float = 0.0 if side < 0 else w
		var inner: float = x0-side*tail_w*0.2
		var outer: float = x0+side*tail_w
		var points := PackedVector2Array([Vector2(inner,drop),Vector2(outer,drop),Vector2(outer-side*notch,drop+h*0.5),Vector2(outer,drop+h),Vector2(inner,drop+h)])
		draw_colored_polygon(points,tail)
		draw_colored_polygon(PackedVector2Array([Vector2(inner,h),Vector2(inner+side*tail_w*0.45,h),Vector2(inner,drop+h)]),tail.darkened(0.25))
	var body := PlushStyle.make({"fill":band,"radius":int(10*unit),"gloss":0.18,"shadow":Color(0.29,0.16,0.25,0.22),"shadow_size":int(8*unit),"shadow_offset":Vector2(0,3*unit)})
	draw_style_box(body,Rect2(Vector2.ZERO,Vector2(w,h)))
	var inset := 5.0*unit
	for y: float in [inset,h-inset]:
		var x := 12.0*unit
		while x < w-12.0*unit:
			draw_line(Vector2(x,y),Vector2(minf(x+6.0*unit,w-12.0*unit),y),seam,1.6*unit,true)
			x += maxf(4.0,10.0*unit)
