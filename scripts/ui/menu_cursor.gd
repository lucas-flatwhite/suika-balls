extends Control
## Selection cursor for menu lists: a felt highlight pill that glides to the hovered or
## focused item, with a bobbing heart pointer. Doubles as the visible keyboard focus.

const TitleFx := preload("res://scripts/ui/title_fx.gd")

var items: Array[BaseButton] = []
var pill: StyleBox
var unit := 1.0
var reduced := false
var heart := Color("f27a9d")
var _rect := Rect2()
var _pill := true
var _shown := 0.0
var _has_target := false
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0

func current_target() -> BaseButton:
	var focused := get_viewport().gui_get_focus_owner()
	for item in items:
		if is_instance_valid(item) and item.is_visible_in_tree() and not item.disabled and item.is_hovered(): return item
	for item in items:
		if is_instance_valid(item) and item == focused and item.is_visible_in_tree(): return item
	return null

func _process(delta: float) -> void:
	_time += delta
	var target := current_target()
	if target != null:
		var goal := Rect2(target.get_global_rect().position-get_global_rect().position,target.size*target.scale)
		_rect = goal if reduced or not _has_target else Rect2(_rect.position.lerp(goal.position,1.0-exp(-delta*18.0)),_rect.size.lerp(goal.size,1.0-exp(-delta*18.0)))
		_has_target = true
		_pill = bool(target.get_meta("cursor_pill",true))
	_shown = move_toward(_shown,1.0 if target != null else 0.0,delta*(60.0 if reduced else 7.0))
	modulate.a = _shown
	queue_redraw()

func _draw() -> void:
	if _shown <= 0.0 or not _has_target: return
	if _pill and pill != null: draw_style_box(pill,_rect)
	var bob := 0.0 if reduced else sin(_time*5.0)*3.0*unit
	var at := Vector2(_rect.position.x-20.0*unit+bob,_rect.get_center().y)
	TitleFx.draw_heart(self,at,24.0*unit,heart,Color(1,1,1,0.95),2.0*unit)
