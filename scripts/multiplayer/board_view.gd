extends Control
## Presentation-only cabinet. Each local board owns its plushies' physics.
signal aimed(world_x: float)
signal dropped
const Balls := preload("res://data/balls.gd")
const BallArt := preload("res://scripts/ball_art.gd")
const CartArt := preload("res://scripts/vfx/cart_art.gd")
const CABINET := Rect2(8,44,704,1072)
const SHELL_INSET := 4.0
const TEXT_BORDER_CLEARANCE := 8.0
var local_player := false
var input_enabled := false:
	set(value):
		input_enabled = value
		if not value: cancel_touch()
var tint := Color("86bfe4")
var border := Color("4f89b2")
var board: Dictionary = {}
var rendered: Dictionary = {}
var world_rect := CABINET
var world_scale := 1.0
var world_offset := Vector2.ZERO
var font: Font
var reduced_motion := false
var _touch_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS if local_player else Control.CURSOR_ARROW
	clip_contents = true
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	get_viewport().size_changed.connect(cancel_touch)

func cancel_touch() -> void:
	_touch_index = -1

func _on_resized() -> void:
	cancel_touch()
	queue_redraw()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree(): cancel_touch()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		cancel_touch()

func _input(event: InputEvent) -> void:
	if _touch_index < 0: return
	if not local_player or not input_enabled or not is_visible_in_tree():
		cancel_touch()
		return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag) or event.index != _touch_index: return
	# GUI touch capture does not guarantee a release outside this Control. Track
	# only the finger acquired in _gui_input, using viewport-to-local coordinates.
	var at: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
	if event is InputEventScreenTouch:
		if event.canceled:
			cancel_touch()
		elif not event.pressed:
			cancel_touch()
			if _aim_touch(at) and local_player and input_enabled: dropped.emit()
	elif event is InputEventScreenDrag:
		_aim_touch(at)
	get_viewport().set_input_as_handled()

func _aim_touch(at: Vector2) -> bool:
	if not get_glass_rect().has_point(at) or world_scale <= 0: return false
	var tank := _tank()
	var world_x := (at.x-world_offset.x)/world_scale
	aimed.emit(clampf(world_x,tank.position.x,tank.end.x))
	return true

func set_snapshot(snapshot: Dictionary) -> void:
	board = snapshot
	var active := {}
	for toy in snapshot.get("toys",[]):
		var id := str(toy.get("id",0))
		active[id] = true
		if not rendered.has(id): rendered[id] = toy.duplicate()
	for id in rendered.keys():
		if not active.has(id): rendered.erase(id)
	queue_redraw()

func _process(delta: float) -> void:
	var weight := 1.0 if reduced_motion else 1.0-exp(-delta*24.0)
	for toy in board.get("toys",[]):
		var id := str(toy.get("id",0))
		if not rendered.has(id): continue
		var shown: Dictionary = rendered[id]
		shown.x = lerpf(float(shown.get("x",0)),float(toy.get("x",0)),weight)
		shown.y = lerpf(float(shown.get("y",0)),float(toy.get("y",0)),weight)
		shown.rotation = lerp_angle(float(shown.get("rotation",0)),float(toy.get("rotation",0)),weight)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not local_player or not input_enabled: return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and _touch_index < 0:
			_touch_index = event.index
			if not _aim_touch(event.position): cancel_touch()
		accept_event()
		return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		if event.device == -1: return
		_update_projection()
		if world_scale <= 0: return
		var world: Vector2 = (event.position-world_offset)/world_scale
		var tank := _tank()
		if tank.grow(12).has_point(world):
			aimed.emit(clampf(world.x,tank.position.x+15,tank.end.x-15))
			if event is InputEventMouseButton: dropped.emit()
		accept_event()

func _tank() -> Rect2:
	var values: Array = board.get("tank",[60,240,600,780])
	return Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))

func _update_projection() -> void:
	# The whole ball cart (handle, wheels and the held ball above the rim) stays visible.
	world_rect = CABINET
	world_scale = minf(size.x/world_rect.size.x,size.y/world_rect.size.y)
	world_offset = (size-world_rect.size*world_scale)*0.5-world_rect.position*world_scale

func get_cabinet_rect() -> Rect2:
	# The visible shell is inset inside the aspect-fit world, not the Control bounds.
	_update_projection()
	var shell := world_rect.grow(-SHELL_INSET)
	return Rect2(world_offset+shell.position*world_scale,shell.size*world_scale)

func get_glass_rect() -> Rect2:
	_update_projection()
	var glass := _tank()
	# Touch aiming also works in the open space above the rim where the next ball waits.
	glass.position.y -= 140
	glass.size.y += 140
	return Rect2(world_offset+glass.position*world_scale,glass.size*world_scale)

func _draw() -> void:
	_update_projection()
	var tank := _tank()
	draw_set_transform(world_offset,0,Vector2.ONE*world_scale)
	CartArt.draw_cart(self,tank)
	# Player colour band on the tray identifies whose cart this is.
	draw_rect(Rect2(tank.position.x+tank.size.x*0.3,tank.end.y+6,tank.size.x*0.4,10),border)
	var danger_y := float(board.get("danger_y",tank.position.y+72))
	var warn := float(board.get("overflow",0)) > 0.0
	var line_color := Color(0.93,0.13,0.16,0.6+0.4*sin(Time.get_ticks_msec()*0.014)) if warn else Color(1.0,0.52,0.30,0.95)
	draw_dashed_line(Vector2(tank.position.x+6,danger_y),Vector2(tank.end.x-6,danger_y),Color(0.12,0.30,0.40,0.35),7,22,true)
	draw_dashed_line(Vector2(tank.position.x+6,danger_y),Vector2(tank.end.x-6,danger_y),line_color,4,22,true)
	for toy in rendered.values(): _draw_toy(toy)
	draw_set_transform(world_offset,0,Vector2.ONE*world_scale)
	var held: Variant = board.get("held",{})
	if held is Dictionary and not held.is_empty():
		var x := float(held.get("x",tank.get_center().x))
		var from_y := float(held.get("y",150))+float(held.get("radius",30))+6
		draw_dashed_line(Vector2(x,from_y),Vector2(x,tank.end.y),Color(1,1,1,0.7),3,14,true)
		_draw_toy(held)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _draw_toy(toy: Dictionary) -> void:
	var tier := clampi(int(toy.get("tier",0)),0,Balls.last_tier())
	var at := Vector2(float(toy.get("x",0)),float(toy.get("y",0)))
	var r := float(toy.get("radius",Balls.radius(tier)))
	BallArt.draw_ball(self,tier,world_offset+at*world_scale,r*world_scale,float(toy.get("rotation",0)),1.0,r*world_scale > 12.0)
