extends StyleBox
## Code-drawn plush/candy material shared by Mushies menus, HUD and modals.
## Layers: soft drop shadow, candy lip (3D depth), body, inner felt shade, top gloss,
## stitched seam and an optional glow. No textures; everything is vector-drawn.

@export var fill := Color("fff8ed")
@export var rim := Color(0,0,0,0)
@export var rim_width := 0
@export var lip := Color(0,0,0,0) ## Colour of the pressed-in bottom depth.
@export var depth := 0.0 ## Lip thickness in pixels (0 = flat felt).
@export var press := 0.0 ## Body offset from the top edge, 0..depth.
@export var radius := 16
@export var gloss := 0.0 ## Alpha of the top highlight band.
@export var shade := 0.0 ## Alpha of the inner felt edge shading.
@export var shade_color := Color("593c49")
@export var stitch := Color(0,0,0,0)
@export var stitch_inset := 6.0
@export var stitch_dash := 7.0
@export var stitch_gap := 5.0
@export var stitch_width := 2.0
@export var shadow := Color(0,0,0,0)
@export var shadow_size := 0
@export var shadow_offset := Vector2(0,4)
@export var glow := Color(0,0,0,0)
@export var glow_size := 0

static func make(values: Dictionary) -> StyleBox:
	var box = load("res://scripts/ui/plush_style.gd").new()
	for key in values: box.set(key,values[key])
	return box

func _flat(color: Color,r: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(r)
	box.anti_aliasing = true
	box.corner_detail = 10
	return box

func _draw(item: RID,rect: Rect2) -> void:
	var body_height := maxf(1.0,rect.size.y-depth)
	var r := mini(radius,int(minf(rect.size.x,body_height)*0.5))
	var body := Rect2(rect.position+Vector2(0,press),Vector2(rect.size.x,body_height))
	if glow.a > 0.0 and glow_size > 0:
		var halo := _flat(Color(glow,glow.a*0.35),r+glow_size/2)
		halo.shadow_color = glow
		halo.shadow_size = glow_size
		halo.draw(item,body.grow(glow_size*0.5))
	if depth > 0.0 or shadow.a > 0.0:
		var base := _flat(lip if depth > 0.0 else fill,r)
		if shadow.a > 0.0:
			base.shadow_color = shadow
			base.shadow_size = shadow_size
			base.shadow_offset = shadow_offset
		base.draw(item,Rect2(rect.position+Vector2(0,depth),Vector2(rect.size.x,body_height)))
	var main := _flat(fill,r)
	if rim_width > 0 and rim.a > 0.0:
		main.border_color = rim
		main.set_border_width_all(rim_width)
	main.draw(item,body)
	if shade > 0.0:
		var edge := _flat(Color(shade_color,0.0),r)
		edge.draw_center = false
		edge.border_blend = true
		edge.border_color = Color(shade_color,shade)
		edge.set_border_width_all(clampi(int(r*0.55),4,14))
		edge.draw(item,body)
	if gloss > 0.0:
		var inset := float(maxi(rim_width+2,3))
		var band := Rect2(body.position+Vector2(inset,inset),Vector2(body.size.x-inset*2,body.size.y*0.42))
		if band.size.x > 2 and band.size.y > 2:
			var shine := _flat(Color(1,1,1,gloss),maxi(2,r-int(inset)))
			shine.corner_radius_bottom_left = maxi(2,int(r*0.35))
			shine.corner_radius_bottom_right = maxi(2,int(r*0.35))
			shine.draw(item,band)
	if stitch.a > 0.0:
		var seam := body.grow(-stitch_inset)
		if seam.size.x > 4 and seam.size.y > 4:
			var points := dashes(seam,maxf(2.0,r-stitch_inset),stitch_dash,stitch_gap)
			if points.size() >= 2:
				RenderingServer.canvas_item_add_multiline(item,points,PackedColorArray([stitch]),stitch_width,true)

static func outline(rect: Rect2,r: float,steps := 6) -> PackedVector2Array:
	## Closed rounded-rectangle path (clockwise from the top-left corner).
	r = minf(r,minf(rect.size.x,rect.size.y)*0.5)
	var points := PackedVector2Array()
	var centers := [rect.position+Vector2(r,r),Vector2(rect.end.x-r,rect.position.y+r),rect.end-Vector2(r,r),Vector2(rect.position.x+r,rect.end.y-r)]
	var starts := [PI,PI*1.5,0.0,PI*0.5]
	for corner in range(4):
		for step in range(steps+1):
			var angle: float = starts[corner]+PI*0.5*float(step)/steps
			points.append(centers[corner]+Vector2(cos(angle),sin(angle))*r)
	points.append(points[0])
	return points

static func dashes(rect: Rect2,r: float,dash: float,gap: float) -> PackedVector2Array:
	## Segment pairs along a rounded rectangle, for a hand-stitched seam.
	var path := outline(rect,r)
	var result := PackedVector2Array()
	dash = maxf(dash,1.0)
	gap = maxf(gap,1.0)
	var period := dash+gap
	var travelled := 0.0
	for index in range(path.size()-1):
		var a := path[index]
		var b := path[index+1]
		var length := a.distance_to(b)
		var at := 0.0
		while at < length:
			var phase := fmod(travelled+at,period)
			var span := minf((dash-phase) if phase < dash else (period-phase),length-at)
			if phase < dash:
				result.append(a.lerp(b,at/length))
				result.append(a.lerp(b,(at+span)/length))
			at += maxf(span,0.001)
		travelled += length
	return result
