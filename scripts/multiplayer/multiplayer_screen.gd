extends Control
## Two local desktop cabinets driven by independent shared-keyboard controls.
signal closed
const UsernameInput := preload("res://scripts/core/username_input.gd")
const LocalMatch := preload("res://scripts/multiplayer/local_match.gd")
const BoardView := preload("res://scripts/multiplayer/board_view.gd")
const BeachBackground := preload("res://scripts/ui/beach_background.gd")
const BallIcon := preload("res://scripts/ui/ball_icon.gd")
const INK := Color("593c49")
const MUTED := Color("866476")
const CREAM := Color("fff8ed")
const ROSE := Color("ebacb7")
const ROSE_BORDER := Color("c58ca6")
const FOCUS := Color("8f5277")
const BLUE := Color("4f89b2")
const RED := Color("bc6572")
const MATCH_FONT_SIZE := 34
const CONTROL_HINT_FONT_SIZE := 17
const TEXT_BORDER_CLEARANCE := 8.0
const FOCUS_BORDER_WIDTH := 3
var game: Node
var local_match: Node
var state: Dictionary = {"status":"idle","players":[],"boards":[],"player_id":1}
var controls: Dictionary = {}
var page: Control
var overlay: Control
var orientation_cover: Control
var local_board: Control
var opponent_board: Control
var entry_mode := "choice"
var phase := ""
var modal_kind := ""
var aim_x := 720.0
var opponent_aim_x := 720.0
var previous_drops := -1
var previous_merges := -1
var opponent_previous_drops := -1
var opponent_previous_merges := -1
var previous_epoch := -1
var _layout_pending := false
var _closing := false
var content_top := 128.0
var _app_visible := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_app_visible = game.device.app_visible
	_theme()
	resized.connect(_schedule_layout)
	_rebuild()

func _theme() -> void:
	theme = Theme.new()
	theme.default_font = game.locale.font
	theme.default_font_size = 18 if is_mobile_layout() else 44
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","LineEdit",INK)
	theme.set_color("font_placeholder_color","LineEdit",MUTED)
	theme.set_stylebox("normal","LineEdit",_style(Color("fffaf3"),Color("cfbbc8")))
	theme.set_stylebox("read_only","LineEdit",_style(Color("fffaf3"),Color("cfbbc8")))
	theme.set_stylebox("focus","LineEdit",_style(Color("fffaf3"),BLUE,3))
	theme.set_constant("separation","VBoxContainer",10 if is_mobile_layout() else 16)
	theme.set_constant("separation","HBoxContainer",8 if is_mobile_layout() else 16)
	for kind in ["Button","CheckButton"]:
		for state_name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: theme.set_color(state_name,kind,INK)
		theme.set_stylebox("normal",kind,_style(Color("fff8ed"),Color("d9bdce")))
		theme.set_stylebox("hover",kind,_style(Color("f9d9dc"),Color("b27a98")))
		theme.set_stylebox("pressed",kind,_style(Color("ebacb7"),INK))
		theme.set_stylebox("disabled",kind,_style(Color("f1e9e4"),Color("d9bdce")))
		theme.set_stylebox("focus",kind,_style(Color.TRANSPARENT,INK,3))

func t(key: String,values: Dictionary = {}) -> String:
	return game.t(key,values)

func _style(color: Color,border := Color.TRANSPARENT,width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(18)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 13
	box.content_margin_bottom = 13
	return box

func _config_style(color: Color,border := Color.TRANSPARENT,width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(14)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = TEXT_BORDER_CLEARANCE+3
	box.content_margin_bottom = TEXT_BORDER_CLEARANCE+3
	return box

func _label(parent: Node,text: String,font_size := 22,color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size*2)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node,key: String,action: Callable,primary := false) -> Button:
	var button := Button.new()
	button.name = key.replace(".","_")
	button.text = t(key)
	button.custom_minimum_size.y = 82
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary: button.add_theme_stylebox_override("normal",_style(Color("d6e9f5"),BLUE))
	button.pressed.connect(func(): game.audio.ensure_music_playing(); game.audio.play_ui("confirm"); action.call())
	button.mouse_entered.connect(func(): game.audio.play_ui("hover"))
	parent.add_child(button)
	controls[key] = button
	return button

func _config_label(parent: Node,text: String,font_size := 18,color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _config_button(parent: Node,key: String,action: Callable,primary := false) -> Button:
	var button := Button.new()
	button.name = key.replace(".","_")
	button.text = t(key)
	button.tooltip_text = button.text
	button.custom_minimum_size.y = 48 if is_mobile_layout() else 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size",18 if is_mobile_layout() else 20)
	button.add_theme_stylebox_override("normal",_config_style(ROSE if primary else CREAM,ROSE_BORDER if primary else Color("d9bdce")))
	button.add_theme_stylebox_override("hover",_config_style(Color("f3c4cc") if primary else Color("f9d9dc"),Color("b27a98")))
	button.add_theme_stylebox_override("pressed",_config_style(Color("df9fab") if primary else ROSE,INK))
	button.add_theme_stylebox_override("disabled",_config_style(Color("f1e9e4"),Color("d9bdce")))
	button.add_theme_stylebox_override("focus",_config_style(Color.TRANSPARENT,FOCUS,3))
	button.pressed.connect(func(): game.audio.ensure_music_playing(); game.audio.play_ui("confirm"); action.call())
	button.mouse_entered.connect(func(): game.audio.play_ui("hover"))
	button.focus_entered.connect(func(): game.audio.play_ui("focus"))
	parent.add_child(button)
	controls[key] = button
	return button

func _compact_match_button(button: Button) -> void:
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size = Vector2.ZERO
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_theme_font_size_override("font_size",MATCH_FONT_SIZE)
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state_name).duplicate()
		box.content_margin_left = 12
		box.content_margin_right = 12
		# Content margins include the border; preserve eight clear pixels even
		# when the three-pixel keyboard-focus frame is visible.
		box.content_margin_top = TEXT_BORDER_CLEARANCE+FOCUS_BORDER_WIDTH
		box.content_margin_bottom = TEXT_BORDER_CLEARANCE+FOCUS_BORDER_WIDTH
		box.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state_name,box)

func _column(parent: Node) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	return column

func _username_input(parent: VBoxContainer) -> LineEdit:
	var compact := not is_mobile_layout() and size.y < 780
	var font_size := 18 if is_mobile_layout() else (22 if compact else 30)
	var content: BoxContainer = _row(parent) if compact else parent
	var label := _label(content,t("ui.name"),font_size/2,MUTED)
	label.add_theme_font_size_override("font_size",font_size)
	if compact:
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var field := UsernameInput.new(game)
	field.custom_minimum_size.y = 48 if is_mobile_layout() else (54 if compact else 58)
	field.add_theme_font_size_override("font_size",font_size)
	field.name_saved.connect(func(value: String):
		if is_instance_valid(local_match): local_match.set_player_name(value)
		_refresh_player_names())
	content.add_child(field)
	controls.username = field
	return field

func _config_username_input(parent: VBoxContainer) -> LineEdit:
	var label := _config_label(parent,t("ui.name"),15,MUTED)
	label.name = "DisplayNameLabel"
	var field := UsernameInput.new(game)
	field.name = "username_input"
	field.custom_minimum_size.y = 48
	field.add_theme_font_size_override("font_size",18 if is_mobile_layout() else 20)
	_configure_field(field)
	field.name_saved.connect(func(value: String):
		if is_instance_valid(local_match): local_match.set_player_name(value)
		_refresh_player_names())
	parent.add_child(field)
	controls.username = field
	return field

func _configure_field(field: LineEdit) -> LineEdit:
	field.add_theme_stylebox_override("normal",_config_style(CREAM,Color("d9bdce")))
	field.add_theme_stylebox_override("read_only",_config_style(CREAM,Color("d9bdce")))
	field.add_theme_stylebox_override("focus",_config_style(CREAM,FOCUS,3))
	return field

func display_name(local: bool) -> String:
	var value := str(game.settings.values.name) if local else ""
	if not value.strip_edges().is_empty(): return value
	return t("mp.player_one" if local else "mp.player_two")

func _refresh_player_names() -> void:
	for local in [true,false]:
		for key in (["local_label","local_name","you_name"] if local else ["opponent_label","opponent_name"]):
			if controls.has(key) and is_instance_valid(controls[key]):
				controls[key].text = display_name(local)
				controls[key].tooltip_text = display_name(local)

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	return row

func _panel(parent: Node,rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(Color("fff8ed"),Color("d9bdce")))
	parent.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	return _column(scroll)

func _center(width: float,height: float) -> Rect2:
	var available_height := maxf(160,size.y-content_top-24)
	var extent := Vector2(minf(width,size.x-48),minf(height,available_height))
	return Rect2(Vector2((size.x-extent.x)*0.5,content_top+(available_height-extent.y)*0.5),extent)

func _config_panel(parent: Node,width: float,height: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "MultiplayerConfigCard"
	panel.add_theme_stylebox_override("panel",_config_style(CREAM,Color("d9bdce"),2))
	parent.add_child(panel)
	var rect := _config_rect(width,height)
	panel.position = rect.position
	panel.size = rect.size
	var scroll := ScrollContainer.new()
	scroll.name = "MultiplayerConfigScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var body := _column(scroll)
	body.add_theme_constant_override("separation",12 if is_mobile_layout() else 14)
	body.minimum_size_changed.connect(_fit_config_panel.bind(panel,body,width,height))
	call_deferred("_fit_config_panel",panel,body,width,height)
	return body
func _fit_config_panel(panel: PanelContainer,body: VBoxContainer,width: float,height_cap: float) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(body) or panel.is_queued_for_deletion() or body.is_queued_for_deletion(): return
	var padding := panel.get_theme_stylebox("panel").get_minimum_size().y
	var content_height := body.get_combined_minimum_size().y+padding
	var rect := _config_rect(width,minf(height_cap,maxf(96.0,content_height)))
	if not panel.position.is_equal_approx(rect.position): panel.position = rect.position
	if not panel.size.is_equal_approx(rect.size): panel.size = rect.size
func _config_rect(width: float,height: float) -> Rect2:
	var side_margin := 12.0 if is_mobile_layout() else 24.0
	var top := 92.0 if is_mobile_layout() else 82.0
	var available := Rect2(side_margin,top,maxf(1,size.x-side_margin*2),maxf(1,size.y-top-24))
	var extent := Vector2(minf(width,available.size.x),minf(height,available.size.y))
	return Rect2(available.get_center()-extent*0.5,extent)

func is_mobile_layout() -> bool:
	# Shared-keyboard mode uses two cabinets, including behind the resize guard.
	return false

func on_device_changed() -> void:
	if is_instance_valid(local_board): local_board.cancel_touch()
	_schedule_layout()

func set_app_visible(visible: bool) -> void:
	_app_visible = visible
	# The local round clock remains shared and continuous while focus changes.
	if is_instance_valid(local_board): local_board.cancel_touch()

func _show_modal(kind: String) -> void:
	if is_instance_valid(local_board): local_board.cancel_touch()
	modal_kind = kind
	_build_overlay()

func _board_state(local: bool) -> Dictionary:
	for board in state.get("boards",[]):
		if (int(board.get("player_id",0)) == int(state.get("player_id",0))) == local: return board
	return {}

func _restore_edit_focus(key: String,caret: int) -> void:
	if _closing or not controls.has(key) or not controls[key] is LineEdit: return
	var field: LineEdit = controls[key]
	# Web opens its hidden keyboard input during focus; publish the caret first.
	field.caret_column = mini(caret,field.text.length())
	field.grab_focus()

func _schedule_layout() -> void:
	if _layout_pending: return
	_layout_pending = true
	call_deferred("_rebuild")

func _rebuild() -> void:
	_layout_pending = false
	if _closing or not is_inside_tree(): return
	var edit_key := ""
	var caret := 0
	var edit_text := ""
	for key in ["username"]:
		if controls.has(key) and is_instance_valid(controls[key]) and controls[key].has_focus():
			edit_key = key
			caret = controls[key].caret_column
			edit_text = controls[key].text
	if is_instance_valid(local_board): local_board.cancel_touch()
	_theme()
	controls.clear()
	local_board = null
	opponent_board = null
	overlay = null
	orientation_cover = null
	if is_instance_valid(page): remove_child(page); page.queue_free()
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var background := BeachBackground.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background)
	var wash := ColorRect.new()
	wash.color = Color(1.0,0.98,0.94,0.55)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(wash)
	phase = str(state.get("status","idle"))
	var match_visible := phase in ["countdown","playing","finished"]
	var heading := _row(page)
	heading.position = Vector2(32 if match_visible else 24,12 if match_visible else 24)
	heading.size = Vector2(size.x-(64 if match_visible else 48),ceilf(game.locale.font.get_height(MATCH_FONT_SIZE))+8 if match_visible else 40)
	heading.name = "MultiplayerScreenHeading"
	var title := _label(heading,"",MATCH_FONT_SIZE/2 if match_visible else 14)
	if match_visible:
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text = t("app.title") if match_visible else t("mp.heading")
	if match_visible:
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		controls.title = title
		var timer := _label(heading,"",MATCH_FONT_SIZE/2,INK)
		timer.autowrap_mode = TextServer.AUTOWRAP_OFF
		timer.text = "3:00"
		timer.custom_minimum_size.x = game.locale.font.get_string_size("3:00",HORIZONTAL_ALIGNMENT_LEFT,-1,MATCH_FONT_SIZE).x+16
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		controls.timer = timer
	content_top = heading.position.y+heading.size.y+8 if match_visible else 82.0
	if match_visible:
		var header: HBoxContainer = heading
		var audio_button := _button(header,"mp.audio",func(): modal_kind = "audio"; _build_overlay())
		var leave_button := _button(header,"mp.leave",_request_leave)
		if match_visible:
			_compact_match_button(audio_button)
			_compact_match_button(leave_button)
	if match_visible:
		# Wrapped labels can report a stale zero-width minimum before the first
		# container pass. The header is one line, with the same padded line metrics
		# as its compact buttons; measuring that line avoids inflating it vertically.
		heading.size.y = ceilf(game.locale.font.get_height(MATCH_FONT_SIZE))+2*(TEXT_BORDER_CLEARANCE+FOCUS_BORDER_WIDTH)
		content_top = heading.position.y+heading.size.y+8
	game.audio.set_music_mood(GameAudio.MusicMood.ACTIVE if phase in ["playing","countdown"] else (GameAudio.MusicMood.GAME_OVER if phase == "finished" else GameAudio.MusicMood.DUCKED))
	if phase in ["countdown","playing","finished"]: _build_match()
	else: _build_choice()
	_refresh_values()
	_build_overlay()
	_orientation()
	if not edit_key.is_empty() and controls.has(edit_key):
		controls[edit_key].text = edit_text
		call_deferred("_restore_edit_focus",edit_key,caret)

func _build_choice() -> void:
	var body := _config_panel(page,620,480)
	_config_username_input(body)
	_config_label(body,t("mp.choose"),28)
	_config_label(body,t("mp.choose_body"),17,MUTED)
	_config_button(body,"mp.local_splitscreen",_start_local,true)
	var back := _config_button(body,"mp.return",_leave)
	back.tooltip_text = t("mp.escape_back")

func end_for_resize() -> void:
	if not is_instance_valid(local_match) or str(local_match.state.status) not in ["countdown","playing"]: return
	modal_kind = ""
	if is_instance_valid(local_board): local_board.cancel_touch()
	local_match.end_for_resize()
	game.set_resize_ended(true)

func _start_local() -> void:
	if not game.device.local_splitscreen_allowed(size): return
	_stop_local()
	entry_mode = "local"
	modal_kind = ""
	local_match = LocalMatch.new()
	local_match.set_player_name(str(game.settings.values.name))
	add_child(local_match)
	local_match.state_changed.connect(_state_changed)
	game.reset_resize_guard()
	local_match.start_match()

func _stop_local() -> void:
	if not is_instance_valid(local_match): return
	local_match.stop()
	local_match.queue_free()
	local_match = null

func _player(local: bool) -> Dictionary:
	for player in state.get("players",[]):
		if (int(player.get("id",0)) == int(state.get("player_id",0))) == local: return player
	return {}

func _match_footer(x: float,width: float,local: bool) -> Control:
	var splitscreen := true
	var prefix := "" if local else "opponent_"
	var hint_key := ("mp.local_controls_one" if local else "mp.local_controls_two") if splitscreen else "mp.controls"
	var font: Font = game.locale.font
	var next_width := 0.0
	# Reserve for every possible preview and the finished-board hint so snapshots
	# cannot move the cabinets or push either footer column over its neighbor.
	for tier in range(10):
		next_width = maxf(next_width,font.get_string_size(t("hud.next",{"toy":game.toy_name(tier)}),HORIZONTAL_ALIGNMENT_LEFT,-1,MATCH_FONT_SIZE).x)
	var hint_width := maxf(font.get_string_size(t(hint_key),HORIZONTAL_ALIGNMENT_LEFT,-1,CONTROL_HINT_FONT_SIZE).x,font.get_string_size(t("mp.board_waiting"),HORIZONTAL_ALIGNMENT_LEFT,-1,CONTROL_HINT_FONT_SIZE).x)
	var available := maxf(80,width-88) # 64px preview and two 12px gaps.
	if next_width+hint_width > available:
		next_width = available*0.45
	else:
		next_width = minf(next_width,available-hint_width)
	hint_width = available-next_width
	var footer := Control.new()
	footer.name = "PlayerOneFooter" if local else "PlayerTwoFooter"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(footer)
	var preview := BallIcon.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(preview)
	preview.size = Vector2(64,64)
	controls[prefix+"next_texture"] = preview
	# Set text only after assigning the wrap width. A zero-width Label otherwise
	# keeps the tall minimum size it computed before joining this manual layout.
	var next_label := _label(footer,"",MATCH_FONT_SIZE/2,MUTED)
	next_label.position = Vector2(76,0)
	next_label.size = Vector2(next_width,64)
	next_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls[prefix+"next"] = next_label
	var keys := _label(footer,"",MATCH_FONT_SIZE/2,(BLUE if local else RED) if splitscreen else MUTED)
	keys.add_theme_font_size_override("font_size",CONTROL_HINT_FONT_SIZE)
	keys.position = Vector2(88+next_width,0)
	keys.size = Vector2(hint_width,64)
	keys.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls[prefix+"controls" if splitscreen else "input_hint"] = keys
	var footer_height := 64.0
	for tier in range(10):
		next_label.text = t("hud.next",{"toy":game.toy_name(tier)})
		footer_height = maxf(footer_height,next_label.get_minimum_size().y)
	for key in [hint_key,"mp.board_waiting"]:
		keys.text = t(key)
		footer_height = maxf(footer_height,keys.get_minimum_size().y)
	next_label.text = t("mp.next")
	keys.text = t(hint_key)
	footer.position = Vector2(x,size.y-footer_height-8)
	footer.size = Vector2(width,footer_height)
	preview.position.y = (footer_height-64)*0.5
	next_label.size.y = footer_height
	keys.size.y = footer_height
	return footer

func _build_match() -> void:
	var splitscreen := true
	var width := (size.x-88)*0.5
	var footer := _match_footer(32,width,true)
	var footer_top := footer.position.y
	if splitscreen:
		var opponent_footer := _match_footer(56+width,width,false)
		footer_top = minf(footer_top,opponent_footer.position.y)
		footer.position.y = footer_top
		opponent_footer.position.y = footer_top
	var label_height := ceilf(game.locale.font.get_height(MATCH_FONT_SIZE))
	var board_top := content_top+label_height+8
	for local in [true,false]:
		var x := 32.0 if local else 56.0+width
		var color := BLUE if local else RED
		var name_width := minf(width*0.56,ceilf(game.locale.font.get_string_size(display_name(local),HORIZONTAL_ALIGNMENT_LEFT,-1,MATCH_FONT_SIZE).x)+2)
		var label := _label(page,"",MATCH_FONT_SIZE/2,color)
		controls["local_label" if local else "opponent_label"] = label
		label.position = Vector2(x,content_top)
		label.size = Vector2(name_width,label_height)
		label.text = display_name(local)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		var score := _label(page,"0",MATCH_FONT_SIZE/2,color)
		score.autowrap_mode = TextServer.AUTOWRAP_OFF
		score.clip_text = true
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		score.position = Vector2(x+name_width+24,content_top)
		score.size = Vector2(width-name_width-24,label_height)
		controls["local_score" if local else "opponent_score"] = score
		var board := BoardView.new()
		board.name = "YourCabinet" if local else "OpponentCabinet"
		board.local_player = local and not splitscreen
		board.tint = Color("9ecde9") if local else Color("eab1b4")
		board.border = color
		board.font = game.locale.font
		board.reduced_motion = game.reduced_motion()
		page.add_child(board)
		board.position = Vector2(x,board_top)
		# Giving the proportional cabinet the reclaimed HUD space grows its visible
		# width by over 25% at the reference desktop size without stretching plushies.
		board.size = Vector2(width,maxf(160,footer_top-board_top-8))
		var status := _label(board,"",MATCH_FONT_SIZE/2,color)
		status.autowrap_mode = TextServer.AUTOWRAP_OFF
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.add_theme_stylebox_override("normal",_style(Color("fff8ed"),color,2))
		status.size = Vector2(minf(300,width-24),64)
		status.text = t("mp.board_finished")
		status.size.y = maxf(64,status.get_combined_minimum_size().y)
		_position_board_status(board,status)
		status.visible = false
		controls["local_status" if local else "opponent_status"] = status
		if local:
			local_board = board
			board.aimed.connect(func(value: float): aim_x = value)
			board.dropped.connect(_drop)
		else: opponent_board = board

func _position_board_status(view: Control,status: Label) -> void:
	# The aspect-fit Control can be wider or taller than the cabinet. Anchor the
	# complete badge inside the glass, clear of the illustrated bottom trim.
	var glass: Rect2 = view.get_glass_rect().grow(-TEXT_BORDER_CLEARANCE)
	# Round toward the interior so fractional aspect-fit coordinates cannot
	# place an edge a floating-point epsilon beyond the eight-pixel boundary.
	glass = Rect2(glass.position.ceil(),glass.end.floor()-glass.position.ceil())
	var badge_width := minf(300,glass.size.x)
	var box: StyleBox = status.get_theme_stylebox("normal")
	var text_width: float = game.locale.font.get_string_size(status.text,HORIZONTAL_ALIGNMENT_LEFT,-1,MATCH_FONT_SIZE).x
	var available := maxf(1,badge_width-box.get_margin(SIDE_LEFT)-box.get_margin(SIDE_RIGHT))
	status.add_theme_font_size_override("font_size",clampi(int(floor(MATCH_FONT_SIZE*available/maxf(1,text_width))),14,MATCH_FONT_SIZE))
	status.size.x = badge_width
	status.size.y = maxf(64,status.get_combined_minimum_size().y)
	status.position = Vector2(glass.get_center().x-status.size.x*0.5,glass.end.y-status.size.y)

func _align_match_footers() -> void:
	var locals := [true,false]
	# A narrower hint may need another line. Settle the footer height and the
	# cabinet's proportional projection together, using the visible shell edge.
	for attempt in range(8):
		var footer_height := 0.0
		var footers: Array[Control] = []
		for local in locals:
			var view: Control = local_board if local else opponent_board
			var key: String = "controls" if local else "opponent_controls"
			var hint: Label = controls[key]
			var footer: Control = hint.get_parent()
			var cabinet_right: float = view.position.x+view.get_cabinet_rect().end.x
			hint.size.x = maxf(1,cabinet_right-footer.position.x-hint.position.x)
			footer_height = maxf(footer_height,maxf(footer.size.y,hint.get_combined_minimum_size().y))
			footers.append(footer)
		var settled := true
		for footer in footers:
			if not is_equal_approx(footer.size.y,footer_height): settled = false
		# The final pass still aligns to the latest projection, without resizing again.
		if settled or attempt == 7:
			for local in [true,false]:
				_position_board_status(local_board if local else opponent_board,controls["local_status" if local else "opponent_status"])
			return
		var footer_top := size.y-footer_height-8
		for footer in footers:
			footer.position.y = footer_top
			footer.size.y = footer_height
			for child in footer.get_children():
				if child is Label: child.size.y = footer_height
				elif child.get_script() == BallIcon: child.position.y = (footer_height-child.size.y)*0.5
		for local in [true,false]:
			var view: Control = local_board if local else opponent_board
			view.size.y = maxf(160,footer_top-view.position.y-8)
			var status: Label = controls["local_status" if local else "opponent_status"]
			_position_board_status(view,status)

func _state_changed(next: Dictionary) -> void:
	if _closing: return
	var old_phase := phase
	state = next
	var next_phase := str(state.get("status","idle"))
	if int(state.get("match_epoch",0)) != previous_epoch:
		previous_epoch = int(state.get("match_epoch",0))
		previous_drops = -1
		previous_merges = -1
		opponent_previous_drops = -1
		opponent_previous_merges = -1
		aim_x = 720
		opponent_aim_x = 720
	if next_phase != old_phase:
		if next_phase == "finished":
			if int(state.get("winner_id",0)) > 0: game.audio.play_victory()
			else: game.audio.play_game_over()
		_rebuild()
	else:
		_refresh_values()
		if phase in ["countdown","finished"] and modal_kind.is_empty(): _refresh_overlay()

func _refresh_values() -> void:
	_refresh_player_names()
	if not is_instance_valid(local_board): return
	for board in state.get("boards",[]):
		var local := int(board.get("player_id",0)) == 1
		var view: Control = local_board if local else opponent_board
		if is_instance_valid(view): view.set_snapshot(board)
		var score: Label = controls["local_score" if local else "opponent_score"]
		score.text = str(int(board.get("score",0)))
		var text_width: float = game.locale.font.get_string_size(score.text,HORIZONTAL_ALIGNMENT_LEFT,-1,MATCH_FONT_SIZE).x
		score.add_theme_font_size_override("font_size",mini(MATCH_FONT_SIZE,maxi(20,int(floor(float(MATCH_FONT_SIZE)*(score.size.x-4)/maxf(1,text_width))))))
		var defeated := str(board.get("outcome","")) == "defeat"
		controls["local_status" if local else "opponent_status"].visible = phase == "playing" and defeated
		controls["controls" if local else "opponent_controls"].text = t("mp.board_waiting" if defeated else ("mp.local_controls_one" if local else "mp.local_controls_two"))
		var prefix := "" if local else "opponent_"
		var tier := int(board.get("next_tier",0))
		controls[prefix+"next_texture"].tier = tier
		controls[prefix+"next"].text = t("hud.next",{"toy":game.toy_name(tier)})
		var drops := int(board.get("drops",0))
		var merges := int(board.get("merges",0))
		var last_drops := previous_drops if local else opponent_previous_drops
		var last_merges := previous_merges if local else opponent_previous_merges
		if phase == "playing":
			if last_drops >= 0 and drops > last_drops: game.audio.play_release()
			if last_merges >= 0 and merges > last_merges: game.audio.play_merge(clampi(int(board.get("held_tier",0)),0,10),false)
		if local:
			previous_drops = drops
			previous_merges = merges
		else:
			opponent_previous_drops = drops
			opponent_previous_merges = merges
	_align_match_footers()
	var seconds := maxi(0,ceili(float(state.get("remaining_seconds",180))))
	controls.timer.text = "%d:%02d" % [seconds/60,seconds%60]
	local_board.input_enabled = false
	opponent_board.input_enabled = false

func _can_play() -> bool:
	return not _closing and phase == "playing" and modal_kind.is_empty() and game.device.local_splitscreen_allowed(size) and is_instance_valid(local_match)

func _can_control(local: bool) -> bool:
	if not _can_play(): return false
	var view := local_board if local else opponent_board
	return is_instance_valid(view) and not view.board.is_empty() and str(view.board.get("outcome","")) != "defeat"

func _process(delta: float) -> void:
	if _closing: return
	_orientation()
	if not _can_play(): return
	var left_direction := float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
	var right_direction := float(Input.is_physical_key_pressed(KEY_L))-float(Input.is_physical_key_pressed(KEY_J))
	if _can_control(true):
		aim_x = clampf(aim_x+left_direction*540.0*delta,415,1025)
		local_match.send_input(1,aim_x,false)
	if _can_control(false):
		opponent_aim_x = clampf(opponent_aim_x+right_direction*540.0*delta,415,1025)
		local_match.send_input(2,opponent_aim_x,false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if not modal_kind.is_empty(): modal_kind = ""; _build_overlay()
			else: _request_leave()
			get_viewport().set_input_as_handled()
		elif _can_play() and event.physical_keycode in [KEY_SPACE,KEY_K]:
			_drop(1 if event.physical_keycode == KEY_SPACE else 2)
			get_viewport().set_input_as_handled()

func _drop(player_id := 1) -> void:
	if not _can_control(player_id == 1): return
	local_match.send_input(player_id,aim_x if player_id == 1 else opponent_aim_x,true)

func _request_leave() -> void:
	if entry_mode == "local":
		modal_kind = "leave"
		_build_overlay()
	else: _leave()

func _leave() -> void:
	if _closing: return
	_closing = true
	_stop_local()
	closed.emit()

func _build_overlay() -> void:
	if is_instance_valid(local_board): local_board.cancel_touch()
	if is_instance_valid(overlay): overlay.queue_free(); page.remove_child(overlay)
	overlay = null
	if modal_kind.is_empty() and phase not in ["countdown","finished"]: return
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.25,0.19,0.24,0.24)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var body := _panel(overlay,_center(1040,780 if modal_kind == "audio" else 640))
	if modal_kind == "leave":
		_label(body,t("mp.leave_title"),32)
		_label(body,t("mp.local_leave_body"),22,MUTED)
		_button(body,"mp.stay",func(): modal_kind = ""; _build_overlay(),true)
		_button(body,"mp.leave",_leave)
	elif modal_kind == "audio":
		_label(body,t("mp.audio"),32)
		_label(body,t("mp.local_live_audio"),18,MUTED)
		var mute := CheckButton.new()
		mute.text = t("ui.muted")
		mute.button_pressed = game.audio_muted
		mute.toggled.connect(func(value: bool): game.setting("muted",value))
		body.add_child(mute)
		for bus in ["master","music","sfx","ui"]:
			var row := _row(body)
			_label(row,t("ui."+bus),19)
			var slider := HSlider.new()
			slider.min_value = 0
			slider.max_value = 100
			slider.step = 5
			slider.value = float(game.settings.values[bus])*100
			slider.custom_minimum_size = Vector2(200,34)
			slider.value_changed.connect(func(value: float): game.setting(bus,value/100.0))
			row.add_child(slider)
		_button(body,"mp.back_match",func(): modal_kind = ""; _build_overlay(),true)
	elif phase == "countdown":
		var compact := size.y < 780
		var heading := _label(body,t("mp.get_ready"),28 if compact else 34)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		controls.countdown = _label(body,"3",56 if compact else 84,BLUE)
		controls.countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(body,t("mp.local_ready_one"),16 if compact else 20,BLUE).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(body,t("mp.local_ready_two"),16 if compact else 20,RED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var winner := int(state.get("winner_id",-1))
		var result_key := "result.game_over" if str(state.get("result_reason","")) == "resize" else ("mp.draw" if winner == -1 else ("mp.player_one_win" if winner == 1 else "mp.player_two_win"))
		_label(body,t(result_key),40)
		var reason := str(state.get("result_reason","timeout"))
		if reason == "time": reason = "timeout"
		_label(body,t("mp.reason_"+reason),21,MUTED)
		controls.rematch = _button(body,"mp.rematch",_rematch,true)
		_button(body,"mp.leave",_leave)
	_refresh_overlay()
	if is_instance_valid(orientation_cover) and modal_kind != "leave": orientation_cover.move_to_front()

func _refresh_overlay() -> void:
	if controls.has("countdown") and is_instance_valid(controls.countdown): controls.countdown.text = str(maxi(1,ceili(float(state.get("countdown",3)))))
	if controls.has("rematch") and is_instance_valid(controls.rematch):
		controls.rematch.disabled = false
		controls.rematch.text = t("mp.rematch")

func _rematch() -> void:
	if is_instance_valid(local_match):
		game.reset_resize_guard()
		local_match.request_rematch()

func _orientation() -> void:
	if game.device.local_splitscreen_allowed(size):
		if is_instance_valid(orientation_cover): orientation_cover.queue_free(); page.remove_child(orientation_cover); orientation_cover = null
		return
	if is_instance_valid(orientation_cover): return
	orientation_cover = Control.new()
	orientation_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(orientation_cover)
	var shade := ColorRect.new()
	shade.color = Color("fff8ed")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orientation_cover.add_child(shade)
	var body := _panel(orientation_cover,_center(880,560))
	_label(body,t("mp.landscape_title"),32)
	_label(body,t("mp.local_landscape_body"),22,MUTED)
	_button(body,"mp.leave",_request_leave)

func _exit_tree() -> void:
	_stop_local()
