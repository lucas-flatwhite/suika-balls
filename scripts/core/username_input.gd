extends LineEdit
## One saved player identity, shared by Settings, Leaderboard and Multiplayer.
signal name_saved(value: String)
var game: Node

func _init(owner_game: Node) -> void:
	game = owner_game
	name = "username_input"
	text = str(game.settings.values.name)
	placeholder_text = game.t("ui.name_placeholder")
	tooltip_text = game.t("ui.name")
	max_length = 20
	context_menu_enabled = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_IBEAM
	text_changed.connect(_save_name)
	text_submitted.connect(func(_value: String): release_focus())
	focus_entered.connect(func(): game.audio.play_ui("focus"))
	focus_entered.connect(_keep_visible)
	focus_exited.connect(_show_saved_name)

func _save_name(value: String) -> void:
	game.setting("name",value)
	name_saved.emit(str(game.settings.values.name))

func _show_saved_name() -> void:
	# Preserve spaces and the caret while typing; show the canonical value on blur.
	text = str(game.settings.values.name)

func _keep_visible() -> void:
	# A node-bound one-shot disconnects if a resize retires this editor.
	if not get_tree().process_frame.is_connected(_reveal_editor):
		get_tree().process_frame.connect(_reveal_editor,CONNECT_ONE_SHOT)

func _reveal_editor() -> void:
	if not is_inside_tree() or not has_focus(): return
	var parent := get_parent()
	while parent != null:
		if parent is ScrollContainer:
			var bounds := get_global_rect()
			var area: Rect2 = parent.get_global_rect()
			if bounds.end.y > area.end.y: parent.scroll_vertical += ceili(bounds.end.y-area.end.y)
			elif bounds.position.y < area.position.y: parent.scroll_vertical += floori(bounds.position.y-area.position.y)
			break
		parent = parent.get_parent()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		release_focus()
		accept_event()
