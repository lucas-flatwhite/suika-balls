extends Control
## 비치볼 머지 화면 구성(모두 한국어):
## 시작 화면(제목·시작·플레이 방법), 게임 HUD(점수·최고·다음 공·일시정지·소리·진화 순서·NEW 알림),
## 일시정지, 게임오버(최종/최고 점수·가장 큰 공·다시하기·공유), 세로 화면 안내.
const Balls := preload("res://data/balls.gd")
const BallIcon := preload("res://scripts/ui/ball_icon.gd")
const BeachBackground := preload("res://scripts/ui/beach_background.gd")

const INK := Color("1f3b4d")
const MUTED := Color("4f6b7a")
const CORAL := Color("ff6b57")
const CORAL_DARK := Color("d94c3a")
const TEAL := Color("1f9fb3")
const TEAL_DARK := Color("137786")
const SUN := Color("ffd23f")
const CARD := Color(1, 1, 1, 1)

var game: Node
var font: Font
var current_route := ""
var u := 1.0
var column := Rect2()
var _background_layer: CanvasLayer
var _background: Control
var _surfaces: Dictionary = {}
var _blockers: Array[Control] = []
var _score_label: Label
var _best_label: Label
var _next_icon: Control
var _sound_buttons: Array[Button] = []
var _evolution: Array[Control] = []
var _toast: PanelContainer
var _toast_icon: Control
var _toast_label: Label
var _toast_time := 0.0
var _banner: Label
var _banner_time := 0.0
var _share_label: Label
var _share_pending := false
var _shown_score := 0
var _last_view := Vector2.ZERO
var _rebuild_queued := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = game.locale.display_font
	var theme_resource := Theme.new()
	theme_resource.default_font = font
	theme_resource.default_font_size = 20
	theme = theme_resource
	_background_layer = CanvasLayer.new()
	_background_layer.layer = -10
	game.add_child.call_deferred(_background_layer)
	_background = BeachBackground.new()
	_background_layer.add_child(_background)
	get_viewport().size_changed.connect(_queue_rebuild)
	rebuild()

func t(key: String, values: Dictionary = {}) -> String:
	return game.t(key, values)

func _queue_rebuild() -> void:
	if _rebuild_queued: return
	_rebuild_queued = true
	call_deferred("_flush_rebuild")

func _flush_rebuild() -> void:
	_rebuild_queued = false
	if get_viewport_rect().size != _last_view: rebuild()

# ------------------------------------------------------------ helpers

func _style(color: Color, radius := 20.0, border := Color.TRANSPARENT, width := 0, shadow := 0.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	if width > 0:
		box.border_color = border
		box.set_border_width_all(width)
	if shadow > 0.0:
		box.shadow_color = Color(0.05, 0.15, 0.25, 0.25)
		box.shadow_size = int(shadow)
		box.shadow_offset = Vector2(0, shadow * 0.4)
	box.anti_aliasing = true
	return box

func _label(parent: Node, text: String, size := 20, color := INK, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", int(size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _outline(label: Label, color: Color, size: int) -> Label:
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", size)
	return label

func _button(parent: Node, text: String, action: Callable, kind := "primary", height := 56.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, height * u)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", int(24 * u))
	var fill := CORAL
	var edge := CORAL_DARK
	var text_color := Color.WHITE
	if kind == "secondary":
		fill = Color("ffffff")
		edge = TEAL
		text_color = TEAL_DARK
	elif kind == "sun":
		fill = SUN
		edge = Color("d99a12")
		text_color = Color("6b4300")
	var radius := height * u * 0.5
	button.add_theme_stylebox_override("normal", _style(fill, radius, edge, int(3 * u), 4 * u))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.08), radius, edge, int(3 * u), 6 * u))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.08), radius, edge, int(3 * u), 1))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), radius, Color("1f3b4d"), int(3 * u)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, text_color)
	button.pressed.connect(func() -> void:
		game.audio.play_ui("click")
		action.call())
	parent.add_child(button)
	return button

func _icon_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(48, 48) * u
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", int(22 * u))
	var radius := 24.0 * u
	button.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.92), radius, TEAL, int(3 * u), 3 * u))
	button.add_theme_stylebox_override("hover", _style(Color("e9fbff"), radius, TEAL, int(3 * u), 4 * u))
	button.add_theme_stylebox_override("pressed", _style(Color("cdeff5"), radius, TEAL_DARK, int(3 * u), 1))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, TEAL_DARK)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _panel(parent: Node, rect: Rect2, color := CARD) -> VBoxContainer:
	var panel := PanelContainer.new()
	var box := _style(color, 30 * u, Color(1, 1, 1, 1), int(4 * u), 14 * u)
	box.content_margin_left = 22 * u
	box.content_margin_right = 22 * u
	box.content_margin_top = 20 * u
	box.content_margin_bottom = 22 * u
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(rect.size.x, 0)
	panel.size = Vector2(rect.size.x, 0)
	panel.position = Vector2(rect.position.x, rect.get_center().y)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", int(12 * u))
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(body)
	get_tree().process_frame.connect(func() -> void:
		if is_instance_valid(panel): panel.size = Vector2(maxf(rect.size.x, panel.get_combined_minimum_size().x), 0), CONNECT_ONE_SHOT)
	# 줄바꿈 문구는 처음엔 한 줄 폭으로 잡혀 패널을 넓힐 수 있어요. 최소 크기가 줄면 원래 폭으로 되돌립니다.
	panel.minimum_size_changed.connect(func() -> void:
		panel.set_deferred("size", Vector2(maxf(rect.size.x, panel.get_combined_minimum_size().x), 0)))
	panel.resized.connect(func() -> void:
		if panel.size.x > maxf(rect.size.x, panel.get_combined_minimum_size().x) + 0.5:
			panel.set_deferred("size", Vector2(maxf(rect.size.x, panel.get_combined_minimum_size().x), 0))
		panel.position = Vector2(rect.get_center().x - panel.size.x * 0.5, clampf(rect.get_center().y - panel.size.y * 0.5, 8, maxf(8, get_viewport_rect().size.y - panel.size.y - 8))))
	return body

func _surface(name_key: String) -> Control:
	var surface := Control.new()
	surface.name = name_key
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	_surfaces[name_key] = surface
	return surface

func _dim(parent: Control, alpha := 0.45) -> ColorRect:
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.16, 0.26, alpha)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shade)
	return shade

func title_font_for_fit() -> Font:
	return font if font != null else ThemeDB.fallback_font

func _sound_text() -> String:
	return t("ui.sound_btn_off") if game.audio_muted else t("ui.sound_btn_on")

# ------------------------------------------------------------ layout

func rebuild() -> void:
	var view := get_viewport_rect().size
	_last_view = view
	for child in get_children(): child.queue_free()
	_surfaces.clear()
	_blockers.clear()
	_sound_buttons.clear()
	_evolution.clear()
	var insets: Vector4 = game.device.safe_insets
	var usable_w: float = view.x - insets.x - insets.z
	var col_w := minf(usable_w, maxf(320.0, view.y * 0.62))
	column = Rect2(insets.x + (usable_w - col_w) * 0.5, insets.y, col_w, view.y - insets.y - insets.w)
	u = clampf(col_w / 430.0, 0.72, 1.6)
	if view.y < 620: u = minf(u, view.y / 760.0)
	_build_gameplay(view)
	_build_title(view)
	_build_pause(view)
	_build_debrief(view)
	_build_error(view)
	_build_rotate(view)
	sync_routes()

func _build_gameplay(view: Vector2) -> void:
	var surface := _surface("gameplay")
	var pad := 10.0 * u
	var bar_h := 64.0 * u
	var top := column.position.y + 8.0 * u
	var bar := HBoxContainer.new()
	bar.position = Vector2(column.position.x + pad, top)
	bar.size = Vector2(column.size.x - pad * 2, bar_h)
	bar.add_theme_constant_override("separation", int(8 * u))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(bar)
	_score_label = _stat_card(bar, t("ui.score"), 1.25)
	_best_label = _stat_card(bar, t("ui.best"), 1.0)
	var next_card := _card(bar, 0.9)
	var next_row := HBoxContainer.new()
	next_row.alignment = BoxContainer.ALIGNMENT_CENTER
	next_row.add_theme_constant_override("separation", int(4 * u))
	next_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_card.add_child(next_row)
	_label(next_row, t("ui.next"), 15 * u, MUTED)
	_next_icon = BallIcon.new()
	_next_icon.custom_minimum_size = Vector2(40, 40) * u
	next_row.add_child(_next_icon)
	var pause := _icon_button(bar, "II", func() -> void:
		game.audio.play_ui("open")
		game.toggle_pause())
	pause.tooltip_text = t("ui.pause")
	var sound := _icon_button(bar, "", func() -> void: game.toggle_audio())
	sound.custom_minimum_size.x = 64 * u
	sound.add_theme_font_size_override("font_size", int(15 * u))
	_sound_buttons.append(sound)
	_blockers.append(bar)
	# Evolution row: 10 icons, made this run = bright, not yet = faded.
	var evo_y := top + bar_h + 8.0 * u
	var evo_h := minf(36.0 * u, (column.size.x - pad * 2) / 10.0 - 2.0)
	var strip := PanelContainer.new()
	var strip_box := _style(Color(1, 1, 1, 0.55), evo_h * 0.5 + 6 * u)
	strip_box.content_margin_left = 8 * u
	strip_box.content_margin_right = 8 * u
	strip_box.content_margin_top = 3 * u
	strip_box.content_margin_bottom = 3 * u
	strip.add_theme_stylebox_override("panel", strip_box)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(2 * u))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)
	for tier in range(Balls.count()):
		var icon := BallIcon.new()
		icon.tier = tier
		icon.dim = true
		icon.custom_minimum_size = Vector2(evo_h, evo_h)
		icon.tooltip_text = Balls.name_of(tier)
		row.add_child(icon)
		_evolution.append(icon)
	strip.reset_size()
	strip.position = Vector2(column.get_center().x - strip.get_combined_minimum_size().x * 0.5, evo_y)
	# Board area below the HUD.
	var board_top := evo_y + evo_h + 12.0 * u
	var board := Rect2(column.position.x + 4 * u, board_top, column.size.x - 8 * u, column.end.y - board_top - 6 * u)
	game.project_board(board)
	# NEW! toast.
	_toast = PanelContainer.new()
	var toast_box := _style(Color("fff6c9"), 26 * u, SUN, int(3 * u), 8 * u)
	toast_box.content_margin_left = 16 * u
	toast_box.content_margin_right = 18 * u
	toast_box.content_margin_top = 6 * u
	toast_box.content_margin_bottom = 6 * u
	_toast.add_theme_stylebox_override("panel", toast_box)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	surface.add_child(_toast)
	var toast_row := HBoxContainer.new()
	toast_row.add_theme_constant_override("separation", int(8 * u))
	toast_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(toast_row)
	_toast_icon = BallIcon.new()
	_toast_icon.custom_minimum_size = Vector2(38, 38) * u
	toast_row.add_child(_toast_icon)
	_toast_label = _label(toast_row, "", 26 * u, Color("8a3b00"))
	_toast.set_meta("anchor_y", game.board_screen_rect.position.y + game.board_screen_rect.size.y * 0.30)
	# Big celebration banner.
	_banner = _label(surface, "", 44 * u, Color("fff4b8"))
	_outline(_banner, Color("c9353f"), int(10 * u))
	_banner.position = Vector2(column.position.x, game.board_screen_rect.get_center().y - 40 * u)
	_banner.size = Vector2(column.size.x, 80 * u)
	_banner.modulate.a = 0.0

func _card(parent: Node, ratio: float) -> PanelContainer:
	var card := PanelContainer.new()
	var box := _style(Color(1, 1, 1, 0.92), 18 * u, Color(1, 1, 1, 1), int(2 * u), 3 * u)
	box.content_margin_left = 8 * u
	box.content_margin_right = 8 * u
	box.content_margin_top = 2 * u
	box.content_margin_bottom = 2 * u
	card.add_theme_stylebox_override("panel", box)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = ratio
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)
	return card

func _stat_card(parent: Node, caption: String, ratio: float) -> Label:
	var card := _card(parent, ratio)
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", int(-4 * u))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	_label(body, caption, 14 * u, MUTED)
	var value := _label(body, "0", 28 * u, INK)
	value.clip_text = true
	return value

func _build_title(view: Vector2) -> void:
	var surface := _surface("title")
	var width := minf(column.size.x - 24 * u, 470 * u)
	var body := _panel(surface, Rect2(column.get_center().x - width * 0.5, column.position.y + 16 * u, width, column.size.y - 32 * u), Color(1, 1, 1, 0.90))
	# 제목 크기는 패널 폭에 맞춥니다(영어 제목이 더 길어요).
	var title_size := 58 * u
	var title_font: Font = title_font_for_fit()
	var title_width := title_font.get_string_size(t("app.title"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(title_size)).x + 24 * u
	var room := width - 56 * u
	if title_width > room: title_size = floorf(title_size * room / title_width)
	var title := _label(body, t("app.title"), title_size, Color("fff4b8"))
	_outline(title, CORAL_DARK, int(12 * u * title_size / (58 * u)))
	_label(body, t("app.subtitle"), 19 * u, MUTED)
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", int(2 * u))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(strip)
	var icon_size := minf(34 * u, (width - 50 * u) / 10.0)
	for tier in range(Balls.count()):
		var icon := BallIcon.new()
		icon.tier = tier
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		strip.add_child(icon)
	var best_line := _label(body, "%s  %d" % [t("ui.best_score"), game.best_score], 19 * u, TEAL_DARK)
	best_line.name = "TitleBest"
	var start := _button(body, t("ui.start"), func() -> void: game.start_stage(0), "primary", 64)
	start.name = "StartButton"
	if game.device.local_splitscreen_allowed(view):
		var duel := _button(body, t("ui.duel"), func() -> void: game.open_multiplayer(), "secondary", 52)
		duel.name = "DuelButton"
	var how := PanelContainer.new()
	var how_box := _style(Color("e9fbff"), 20 * u, Color("bfe9f2"), int(2 * u))
	how_box.content_margin_left = 14 * u
	how_box.content_margin_right = 14 * u
	how_box.content_margin_top = 10 * u
	how_box.content_margin_bottom = 12 * u
	how.add_theme_stylebox_override("panel", how_box)
	how.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(how)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", int(4 * u))
	how.add_child(lines)
	_label(lines, t("ui.howto.title"), 20 * u, TEAL_DARK)
	for key in ["ui.howto.1", "ui.howto.2", "ui.howto.3"]:
		var line := _label(lines, "· " + t(key), 16 * u, INK, HORIZONTAL_ALIGNMENT_LEFT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not game.device.use_mobile_hud(view):
		var keys := _label(lines, t("ui.keys"), 14 * u, MUTED)
		keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sound := _icon_button(surface, "", func() -> void: game.toggle_audio())
	sound.custom_minimum_size = Vector2(72, 44) * u
	sound.add_theme_font_size_override("font_size", int(15 * u))
	sound.position = Vector2(column.end.x - 84 * u, column.position.y + 4 * u)
	sound.reset_size()
	_sound_buttons.append(sound)
	# 언어 전환(한국어 ↔ English): 시작 화면 왼쪽 위.
	var language := _icon_button(surface, t("ui.language_switch"), func() -> void: game.toggle_language())
	language.name = "LanguageButton"
	language.tooltip_text = t("ui.language_label")
	language.custom_minimum_size = Vector2(84, 44) * u
	language.add_theme_font_size_override("font_size", int(15 * u))
	language.position = Vector2(column.position.x + 12 * u, column.position.y + 4 * u)
	language.reset_size()

func _build_pause(_view: Vector2) -> void:
	var surface := _surface("pause")
	_dim(surface)
	var width := minf(column.size.x - 40 * u, 380 * u)
	var body := _panel(surface, Rect2(column.get_center().x - width * 0.5, column.get_center().y - 190 * u, width, 380 * u))
	_label(body, t("ui.paused"), 36 * u, TEAL_DARK)
	var resume := _button(body, t("ui.resume"), func() -> void: game.close_modal(), "primary", 58)
	resume.name = "ResumeButton"
	_button(body, t("ui.restart"), func() -> void: game.restart_game(), "secondary", 52)
	var sound := _button(body, "", func() -> void: game.toggle_audio(), "secondary", 52)
	_sound_buttons.append(sound)
	var language := _button(body, "%s · %s" % [t("ui.language_label"), t("ui.language_switch")], func() -> void: game.toggle_language(), "secondary", 52)
	language.name = "PauseLanguageButton"
	_button(body, t("ui.title"), func() -> void: game.return_title(), "secondary", 52)

func _build_debrief(_view: Vector2) -> void:
	var surface := _surface("debrief")
	_dim(surface, 0.40)
	var width := minf(column.size.x - 32 * u, 400 * u)
	var body := _panel(surface, Rect2(column.get_center().x - width * 0.5, column.get_center().y - 260 * u, width, 520 * u))
	var heading := _label(body, t("ui.gameover"), 46 * u, Color("fff4b8"))
	_outline(heading, CORAL_DARK, int(10 * u))
	_label(body, t("ui.final_score"), 18 * u, MUTED)
	var final_score := _label(body, "0", 58 * u, INK)
	final_score.name = "FinalScore"
	var record := _label(body, t("ui.new_record"), 20 * u, CORAL)
	record.name = "NewRecord"
	var best_line := _label(body, "", 19 * u, TEAL_DARK)
	best_line.name = "BestLine"
	var biggest := HBoxContainer.new()
	biggest.alignment = BoxContainer.ALIGNMENT_CENTER
	biggest.add_theme_constant_override("separation", int(10 * u))
	biggest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(biggest)
	var icon := BallIcon.new()
	icon.name = "BiggestIcon"
	icon.custom_minimum_size = Vector2(56, 56) * u
	biggest.add_child(icon)
	var caption := VBoxContainer.new()
	caption.add_theme_constant_override("separation", int(-2 * u))
	biggest.add_child(caption)
	_label(caption, t("ui.biggest"), 15 * u, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	var name_label := _label(caption, "", 26 * u, INK, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.name = "BiggestName"
	var restart := _button(body, t("ui.restart"), func() -> void: game.restart_game(), "primary", 62)
	restart.name = "RestartButton"
	var share := _button(body, t("ui.share"), _share, "sun", 52)
	share.name = "ShareButton"
	_share_label = _label(body, "", 16 * u, TEAL_DARK)
	_share_label.visible = false
	_button(body, t("ui.title"), func() -> void: game.return_title(), "secondary", 48)

func _build_error(_view: Vector2) -> void:
	var surface := _surface("error")
	_dim(surface, 0.5)
	var width := minf(column.size.x - 40 * u, 380 * u)
	var body := _panel(surface, Rect2(column.get_center().x - width * 0.5, column.get_center().y - 120 * u, width, 240 * u))
	_label(body, t("error.title"), 28 * u, CORAL_DARK)
	var message := _label(body, t(game.error_key), 18 * u, INK)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(body, t("ui.title"), func() -> void: game.return_title(), "primary", 54)

func _build_rotate(_view: Vector2) -> void:
	var surface := _surface("rotate")
	_dim(surface, 0.85)
	var label := _label(surface, t("ui.rotate"), 30 * u, Color.WHITE)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ------------------------------------------------------------ routes

func sync_routes() -> void:
	if _surfaces.is_empty(): return
	var route: String = game.routes.route
	var modal: String = game.routes.modal()
	var entering := route != current_route
	current_route = route
	_surfaces.title.visible = route == "title"
	_surfaces.gameplay.visible = route == "gameplay" or route == "debrief" or (route == "gameplay" and modal == "pause")
	_surfaces.pause.visible = route == "gameplay" and modal == "pause"
	_surfaces.debrief.visible = route == "debrief"
	_surfaces.error.visible = route == "error"
	_surfaces.rotate.visible = game.device.portrait_blocked and not game.multiplayer_active()
	if route == "title":
		var best_line := _surfaces.title.find_child("TitleBest", true, false) as Label
		if best_line: best_line.text = "%s  %d" % [t("ui.best_score"), game.best_score]
	if route == "debrief" and entering: _fill_debrief()
	_refresh_sound()
	# Focus: menus get keyboard focus; gameplay keeps none so Space only drops.
	if route == "gameplay" and modal == "":
		get_viewport().gui_release_focus()
	elif route == "gameplay" and modal == "pause":
		_focus(_surfaces.pause.find_child("ResumeButton", true, false))
	elif route == "title" and entering:
		_focus(_surfaces.title.find_child("StartButton", true, false))
	elif route == "debrief" and entering:
		_focus(_surfaces.debrief.find_child("RestartButton", true, false))

func _focus(control: Node) -> void:
	if control is Control:
		(control as Control).call_deferred("grab_focus")

func _fill_debrief() -> void:
	var surface: Control = _surfaces.debrief
	(surface.find_child("FinalScore", true, false) as Label).text = str(game.score)
	(surface.find_child("NewRecord", true, false) as Label).visible = game.new_best
	(surface.find_child("BestLine", true, false) as Label).text = "%s  %d" % [t("ui.best_score"), game.best_score]
	var tier: int = game.session.highest
	(surface.find_child("BiggestIcon", true, false)).tier = tier
	(surface.find_child("BiggestName", true, false) as Label).text = Balls.name_of(tier)
	_set_share_text("")
	_share_pending = false

func _refresh_sound() -> void:
	for button in _sound_buttons:
		if is_instance_valid(button): button.text = _sound_text()

# ------------------------------------------------------------ events

func announce_new(tier: int) -> void:
	if not is_instance_valid(_toast): return
	_toast_icon.tier = tier
	_toast_label.text = t("ui.new_ball", {"ball": Balls.name_of(tier)})
	_toast.reset_size()
	_toast_time = 1.8
	if tier < _evolution.size(): _evolution[tier].highlight = 1.2

func celebrate(points: int) -> void:
	if not is_instance_valid(_banner): return
	_banner.text = t("ui.final_bonus", {"points": points})
	_banner_time = 2.4

func _share() -> void:
	var tier: int = game.session.highest
	var text := t("ui.share_text", {"score": game.score, "ball": Balls.name_of(tier)})
	if OS.has_feature("web"):
		var code := """(function(t){
var w=window; w.__bmShareState='pending';
var url=String(location.href).split('#')[0];
function legacy(full){try{var a=document.createElement('textarea');a.value=full;a.setAttribute('readonly','');a.style.position='fixed';a.style.opacity='0';document.body.appendChild(a);a.select();var ok=document.execCommand('copy');document.body.removeChild(a);w.__bmShareState=ok?'copied':'failed';}catch(e){w.__bmShareState='failed';}}
function copy(){var full=t+' '+url;if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(full).then(function(){w.__bmShareState='copied';},function(){legacy(full);});}else{legacy(full);}}
if(navigator.share){navigator.share({title:'비치볼 머지',text:t,url:url}).then(function(){w.__bmShareState='shared';},function(e){if(e&&e.name==='AbortError'){w.__bmShareState='cancel';}else{copy();}});}else{copy();}
})(%s)""" % JSON.stringify(text)
		JavaScriptBridge.eval(code, true)
		_share_pending = true
	else:
		DisplayServer.clipboard_set(text)
		_set_share_text(t("ui.copied"))

func _set_share_text(text: String) -> void:
	_share_label.text = text
	_share_label.visible = text != ""

func _poll_share() -> void:
	if not _share_pending or not OS.has_feature("web"): return
	var state = JavaScriptBridge.eval("window.__bmShareState||''", true)
	if not state is String or state == "pending" or state == "": return
	_share_pending = false
	match state:
		"shared": _set_share_text(t("ui.shared"))
		"copied": _set_share_text(t("ui.copied"))
		"cancel": _set_share_text("")
		_: _set_share_text(t("ui.share_failed"))

# ------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if not is_instance_valid(_score_label): return
	if current_route == "gameplay" or current_route == "debrief":
		var target: int = game.score
		if _shown_score != target:
			# 점수가 오를 때만 숫자를 굴려 보여 주고, 내려갈 때(다시 하기로 0점)는 바로 맞춥니다.
			# 예전엔 내려갈 때도 maxi(1, …)로 +1씩 더해 목표에서 멀어지며 끝없이 올라갔어요.
			if target < _shown_score or target - _shown_score < 2 or game.reduced_motion():
				_shown_score = target
			else:
				_shown_score += maxi(1, (target - _shown_score) / 4)
		_score_label.text = str(_shown_score)
		_best_label.text = str(maxi(game.best_score, target))
		_next_icon.tier = game.next_tier
		for tier in range(_evolution.size()):
			var made: bool = game.discovered[tier]
			if _evolution[tier].dim == made: _evolution[tier].dim = not made
	else:
		_shown_score = 0
	if _toast_time > 0.0:
		_toast_time = maxf(0.0, _toast_time - delta)
		var appear := clampf((1.8 - _toast_time) / 0.18, 0.0, 1.0)
		var fade := clampf(_toast_time / 0.35, 0.0, 1.0)
		_toast.modulate.a = minf(appear, fade)
		var lift := (1.0 - appear) * 20.0 * u
		_toast.position = Vector2(column.get_center().x - _toast.size.x * 0.5, float(_toast.get_meta("anchor_y")) + lift)
		_toast.scale = Vector2.ONE
	elif is_instance_valid(_toast): _toast.modulate.a = 0.0
	if _banner_time > 0.0:
		_banner_time = maxf(0.0, _banner_time - delta)
		_banner.modulate.a = clampf(_banner_time / 0.5, 0.0, 1.0)
		var pulse := 1.0 + 0.06 * sin(_banner_time * 10.0)
		_banner.pivot_offset = _banner.size * 0.5
		_banner.scale = Vector2.ONE * pulse
	elif is_instance_valid(_banner): _banner.modulate.a = 0.0
	_poll_share()
	if is_instance_valid(_surfaces.get("rotate")):
		var blocked: bool = game.device.portrait_blocked and not game.multiplayer_active()
		if _surfaces.rotate.visible != blocked: _surfaces.rotate.visible = blocked

func apply_presentation() -> void:
	if not is_inside_tree(): return
	modulate.a = float(game.tweaks.value("ui.hud.opacity"))
	if is_instance_valid(_background): _background.animate = not game.reduced_motion()
	_refresh_sound()

func dismiss_editor() -> void:
	pass

func active_surface() -> Control:
	return self

## 게임 영역 위에 있는 버튼(상단 바)을 누를 때는 공이 떨어지지 않습니다.
func blocks_pointer(at: Vector2) -> bool:
	for control in _blockers:
		if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(at):
			return true
	return game.routes.modal() != "" or current_route != "gameplay"
