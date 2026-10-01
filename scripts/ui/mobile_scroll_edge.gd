extends CanvasLayer
## A single visible track for the active mobile surface; never deletes native bars.
var game: Node
var bar: VScrollBar
var target: ScrollContainer
var _cached_scope: Node
var _candidates: Array[Node] = []
var _dirty := true

func _ready() -> void:
	name = "MobileScrollEdge"
	layer = 90
	bar = VScrollBar.new()
	bar.name = "MobileEdgeScrollbar"
	bar.focus_mode = Control.FOCUS_NONE
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var transparent := Image.create(1,1,false,Image.FORMAT_RGBA8)
	transparent.fill(Color.TRANSPARENT)
	var icon := ImageTexture.create_from_image(transparent)
	for key in ["increment","decrement","increment_highlight","decrement_highlight","increment_pressed","decrement_pressed"]:
		bar.add_theme_icon_override(key,icon)
	for key in ["scroll","scroll_focus","grabber","grabber_highlight","grabber_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("ead9df") if key.begins_with("scroll") else Color("947385")
		box.set_corner_radius_all(3)
		box.content_margin_left = 3
		box.content_margin_right = 3
		bar.add_theme_stylebox_override(key,box)
	bar.value_changed.connect(_scroll_changed)
	add_child(bar)
	bar.hide()
	get_tree().tree_changed.connect(_invalidate)

func _invalidate() -> void:
	_dirty = true

func _scope() -> Node:
	if game.multiplayer_active():
		var screen = game._multiplayer_screen
		# Local play keeps Leave above its orientation cover so a rotated player can exit.
		if screen.modal_kind == "leave" and is_instance_valid(screen.overlay) and screen.overlay.visible: return screen.overlay
		if is_instance_valid(screen.orientation_cover) and screen.orientation_cover.visible: return screen.orientation_cover
		if is_instance_valid(screen.overlay) and screen.overlay.visible: return screen.overlay
		return screen.page
	return game._hud.active_surface()

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game._hud): return
	var mobile: bool = game.device.use_mobile_hud(get_viewport().get_visible_rect().size)
	var scope := _scope()
	if _dirty or scope != _cached_scope:
		_cached_scope = scope
		_candidates = game.find_children("*","ScrollContainer",true,false)
		_dirty = false
	target = null
	for node in _candidates:
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		var scroll := node as ScrollContainer
		if mobile:
			if not scroll.has_meta("edge_original_mode"):
				scroll.set_meta("edge_original_mode",scroll.vertical_scroll_mode)
				scroll.set_meta("edge_original_horizontal",scroll.horizontal_scroll_mode)
			scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		else:
			if scroll.has_meta("edge_original_mode"):
				scroll.vertical_scroll_mode = int(scroll.get_meta("edge_original_mode"))
				scroll.horizontal_scroll_mode = int(scroll.get_meta("edge_original_horizontal"))
				scroll.remove_meta("edge_original_mode")
				scroll.remove_meta("edge_original_horizontal")
			continue
		if not is_instance_valid(scope) or not (scope == scroll or scope.is_ancestor_of(scroll)) or not scroll.is_visible_in_tree(): continue
		var native := scroll.get_v_scroll_bar()
		if native.max_value-native.page <= 1: continue
		# Prefer the largest body, never a nested input or a hidden underlying card.
		if target == null or scroll.size.y > target.size.y: target = scroll
	bar.visible = mobile and is_instance_valid(target)
	if not bar.visible: return
	var bounds := target.get_global_rect()
	var view := get_viewport().get_visible_rect().size
	var top := maxf(0,bounds.position.y)
	var bottom := minf(view.y,bounds.end.y)
	bar.position = Vector2(view.x-6,top)
	bar.size = Vector2(6,maxf(1,bottom-top))
	var native := target.get_v_scroll_bar()
	# Range setters can emit value_changed while clamping the previous surface.
	bar.set_block_signals(true)
	bar.min_value = native.min_value
	bar.max_value = native.max_value
	bar.page = native.page
	bar.set_value_no_signal(target.scroll_vertical)
	bar.set_block_signals(false)
	# Hidden native tracks should not suppress keyboard/gamepad focus reveal.
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Control and target.is_ancestor_of(focused) and focused.is_visible_in_tree():
		if Input.is_action_just_pressed("ui_focus_next") or Input.is_action_just_pressed("ui_focus_prev"):
			_reveal.call_deferred(weakref(target),weakref(focused))

func _reveal(scroll_ref: WeakRef,control_ref: WeakRef) -> void:
	var scroll = scroll_ref.get_ref()
	var control = control_ref.get_ref()
	if not is_instance_valid(scroll) or not is_instance_valid(control) or not control.is_visible_in_tree(): return
	var viewport_rect: Rect2 = scroll.get_global_rect()
	var bounds: Rect2 = control.get_global_rect()
	if bounds.end.y > viewport_rect.end.y: scroll.scroll_vertical += ceili(bounds.end.y-viewport_rect.end.y)
	elif bounds.position.y < viewport_rect.position.y: scroll.scroll_vertical += floori(bounds.position.y-viewport_rect.position.y)

func _scroll_changed(value: float) -> void:
	if is_instance_valid(target): target.scroll_vertical = roundi(value)
