extends RefCounted
## Tiny procedural icons for themed widgets (toggle switch, slider knob), rasterised once at
## runtime from signed-distance shapes. No binary assets are shipped for these.

static var _cache: Dictionary = {}

static func _coverage(distance: float) -> float:
	return clampf(0.5-distance,0.0,1.0)

static func _blend(under: Color,over: Color,alpha: float) -> Color:
	var a := over.a*alpha
	var out_a := a+under.a*(1.0-a)
	if out_a <= 0.0: return Color(0,0,0,0)
	var rgb := (Color(over.r,over.g,over.b)*a+Color(under.r,under.g,under.b)*under.a*(1.0-a))/out_a
	return Color(rgb.r,rgb.g,rgb.b,out_a)

static func _pill_distance(p: Vector2,center: Vector2,half: Vector2) -> float:
	var r := half.y
	var q := Vector2(maxf(absf(p.x-center.x)-(half.x-r),0.0),absf(p.y-center.y))
	return q.length()-r

## Felt toggle: pink candy track with a cream knob on the right when on; lilac-grey when off.
static func switch(on: bool,disabled := false,scale := 1.0) -> ImageTexture:
	var key := "switch_%s_%s_%.2f" % [on,disabled,scale]
	if _cache.has(key): return _cache[key]
	var w := int(round(54*scale))
	var h := int(round(32*scale))
	var image := Image.create(w,h,false,Image.FORMAT_RGBA8)
	var track := Color("f596b0") if on else Color("dccfe6")
	var rim := Color("c9678a") if on else Color("b9a6cc")
	if disabled:
		track.a = 0.45
		rim.a = 0.45
	var center := Vector2(w,h)*0.5
	var half := Vector2(w*0.5-1.5,h*0.5-3.0)
	var knob_r := half.y-2.5*scale
	var knob_c := Vector2(center.x+(half.x-half.y) if on else center.x-(half.x-half.y),center.y)
	for y in range(h):
		for x in range(w):
			var p := Vector2(x+0.5,y+0.5)
			var color := Color(0,0,0,0)
			var shadow := _pill_distance(p-Vector2(0,1.5*scale),center,half)
			color = _blend(color,Color(0.29,0.16,0.25,0.18),_coverage(shadow))
			var d := _pill_distance(p,center,half)
			color = _blend(color,rim,_coverage(d))
			color = _blend(color,track,_coverage(d+1.4*scale))
			# Top gloss inside the track.
			if p.y < center.y-1.0: color = _blend(color,Color(1,1,1,0.28),_coverage(d+3.0*scale))
			var kd := p.distance_to(knob_c+Vector2(0,1.2*scale))-knob_r
			color = _blend(color,Color(0.29,0.16,0.25,0.22),_coverage(kd))
			kd = p.distance_to(knob_c)-knob_r
			color = _blend(color,Color("fffaf4") if not disabled else Color(1,0.98,0.95,0.6),_coverage(kd))
			var gloss := p.distance_to(knob_c-Vector2(knob_r*0.3,knob_r*0.35))-knob_r*0.35
			color = _blend(color,Color(1,1,1,0.9),_coverage(gloss)*0.6)
			image.set_pixel(x,y,color)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

## Slider knob: cream button with a berry ring and a tiny heart-pink core.
static func knob(highlight := false,scale := 1.0) -> ImageTexture:
	var key := "knob_%s_%.2f" % [highlight,scale]
	if _cache.has(key): return _cache[key]
	var size := int(round(28*scale))
	var image := Image.create(size,size,false,Image.FORMAT_RGBA8)
	var center := Vector2(size,size)*0.5
	var r := size*0.5-2.5
	for y in range(size):
		for x in range(size):
			var p := Vector2(x+0.5,y+0.5)
			var color := Color(0,0,0,0)
			color = _blend(color,Color(0.29,0.16,0.25,0.25),_coverage(p.distance_to(center+Vector2(0,1.5))-r))
			color = _blend(color,Color("b24d7c") if highlight else Color("d27a9d"),_coverage(p.distance_to(center)-r))
			color = _blend(color,Color("fffaf4"),_coverage(p.distance_to(center)-(r-2.2*scale)))
			color = _blend(color,Color("f596b0"),_coverage(p.distance_to(center)-r*0.32))
			color = _blend(color,Color(1,1,1,0.85),_coverage(p.distance_to(center-Vector2(r*0.35,r*0.4))-r*0.22)*0.8)
			image.set_pixel(x,y,color)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
