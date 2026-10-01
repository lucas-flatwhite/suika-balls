extends Control
## Compact player settings modal. The HUD owns route lifetime; this control owns layout.

const UsernameInput := preload("res://scripts/core/username_input.gd")
const PlushStyle := preload("res://scripts/ui/plush_style.gd")
const PlushIcons := preload("res://scripts/ui/plush_icons.gd")

const INK := Color("593c49")
const MUTED := Color("866476")
const CREAM := Color("fff8ed")
const SOFT_CREAM := Color("fff3e5")
const PINK := Color("ebacb7")
const PINK_LIGHT := Color("f9d9dc")
const PINK_BORDER := Color("d9bdce")
const FOCUS := Color("8f5277")
const SAFE_MARGIN := 12.0
const DESKTOP_CARD := Vector2(920,640)
const MIN_TARGET := 44.0

var hud: Control
var game: Node
var card: PanelContainer
var groups: GridContainer
var close_button: Button
var _scroll: ScrollContainer
var _save_note: Label
var _last_saved: Variant = null

func _ready() -> void:
	if hud == null:
		push_error("SettingsDialog requires its hud before entering the tree.")
		return
	game = hud.game
	name = "SettingsDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _make_theme()
	_build()
	resized.connect(_layout_card)
	call_deferred("_layout_card")
	if hud.has_method("_claim_intro") and hud._claim_intro("modal:settings"):
		modulate.a = 0.0
		create_tween().tween_property(self,"modulate:a",1.0,0.18)
		card.scale = Vector2.ONE*0.92
		var pop := card.create_tween()
		pop.tween_callback(func(): if is_instance_valid(card): card.pivot_offset = card.size*0.5)
		pop.tween_property(card,"scale",Vector2.ONE,0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = game.locale.font
	result.default_font_size = _font_size(16)
	result.set_color("font_color","Label",INK)
	result.set_color("font_color","Button",INK)
	for control_type in ["Button","CheckButton","OptionButton"]:
		result.set_font("font",control_type,game.locale.medium_font)
	result.set_color("font_hover_color","Button",INK)
	result.set_color("font_pressed_color","Button",INK)
	result.set_color("font_focus_color","Button",INK)
	result.set_color("font_color","CheckButton",INK)
	result.set_color("font_hover_color","CheckButton",INK)
	result.set_color("font_focus_color","CheckButton",INK)
	result.set_color("font_pressed_color","CheckButton",INK)
	result.set_color("font_color","OptionButton",INK)
	result.set_color("font_hover_color","OptionButton",INK)
	result.set_color("font_focus_color","OptionButton",INK)
	result.set_color("font_pressed_color","OptionButton",INK)
	result.set_color("font_color","LineEdit",INK)
	result.set_color("font_placeholder_color","LineEdit",MUTED)
	result.set_constant("separation","VBoxContainer",10)
	result.set_constant("separation","HBoxContainer",10)
	# Plush materials shared with the HUD: candy buttons, felt fields, felt toggle rows.
	for state in ["normal","hover","pressed","focus","disabled"]:
		result.set_stylebox(state,"Button",_padded(hud.plush("cream",state),12,8))
		result.set_stylebox(state,"OptionButton",_padded(hud.plush("field",state),12,8))
		result.set_stylebox(state,"LineEdit",_padded(hud.plush("field",state),12,8))
	result.set_stylebox("read_only","LineEdit",_padded(hud.plush("field","disabled"),12,8))
	var rows := {"normal":Color("fffdf9"),"hover":Color("fff0f3"),"pressed":Color("fff4f0"),"hover_pressed":Color("ffe9ee"),"disabled":Color(CREAM,0.6)}
	for state in rows:
		result.set_stylebox(state,"CheckButton",PlushStyle.make({"fill":rows[state],"rim":Color("ecd3de"),"rim_width":1,"radius":14,"gloss":0.35,
			"shadow":Color(0.29,0.16,0.25,0.08),"shadow_size":3,"shadow_offset":Vector2(0,2)}))
		result.get_stylebox(state,"CheckButton").content_margin_left = 12
		result.get_stylebox(state,"CheckButton").content_margin_right = 12
		result.get_stylebox(state,"CheckButton").content_margin_top = 8
		result.get_stylebox(state,"CheckButton").content_margin_bottom = 8
	result.set_stylebox("focus","CheckButton",PlushStyle.make({"fill":Color(0,0,0,0),"rim":FOCUS,"rim_width":2,"radius":14,"glow":Color(PINK,0.5),"glow_size":6}))
	result.set_icon("checked","CheckButton",PlushIcons.switch(true))
	result.set_icon("unchecked","CheckButton",PlushIcons.switch(false))
	result.set_icon("checked_disabled","CheckButton",PlushIcons.switch(true,true))
	result.set_icon("unchecked_disabled","CheckButton",PlushIcons.switch(false,true))
	var track := PlushStyle.make({"fill":Color("f3e2ea"),"rim":Color("dcbfd0"),"rim_width":1,"radius":7,"shade":0.1})
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := PlushStyle.make({"fill":Color("f596b0"),"radius":7,"gloss":0.35})
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	result.set_stylebox("slider","HSlider",track)
	result.set_stylebox("grabber_area","HSlider",fill)
	result.set_stylebox("grabber_area_highlight","HSlider",fill)
	result.set_icon("grabber","HSlider",PlushIcons.knob(false))
	result.set_icon("grabber_highlight","HSlider",PlushIcons.knob(true))
	var popup: StyleBox = hud.plush("felt")
	popup.content_margin_left = 12
	popup.content_margin_right = 12
	popup.content_margin_top = 10
	popup.content_margin_bottom = 10
	result.set_stylebox("panel","PopupMenu",popup)
	result.set_stylebox("hover","PopupMenu",PlushStyle.make({"fill":Color(PINK,0.55),"radius":10}))
	result.set_color("font_color","PopupMenu",INK)
	var seam := StyleBoxLine.new()
	seam.color = Color("e791ad",0.6)
	seam.thickness = 2
	result.set_stylebox("separator","HSeparator",seam)
	return result

func _padded(box: StyleBox,horizontal: float,vertical: float) -> StyleBox:
	# Keep the dialog's compact 44 px rows: the candy lip is folded into the vertical padding.
	var depth: float = box.get("depth") if box.get("depth") != null else 0.0
	var press: float = box.get("press") if box.get("press") != null else 0.0
	var base := maxf(2.0,vertical-depth*0.5)
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = base+press
	box.content_margin_bottom = base+depth-press
	return box

func _box(fill: Color, outline := Color.TRANSPARENT, radius := 14, horizontal := 12, vertical := 8, width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = outline
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
	return box

func _font_size(base: int) -> int:
	var text_scale := float(game.tweaks.value("ui.text.scale")) if game != null else 1.0
	return roundi(base * clampf(get_viewport_rect().size.y/900.0,0.92,1.08) * text_scale)

func _build() -> void:
	var shade := ColorRect.new()
	shade.name = "ModalShade"
	shade.color = Color(0.26,0.13,0.22,0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	if hud.has_method("vignette_texture"):
		var vignette := TextureRect.new()
		vignette.name = "Vignette"
		vignette.texture = hud.vignette_texture()
		vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vignette.stretch_mode = TextureRect.STRETCH_SCALE
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.add_child(vignette)
		vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	card = PanelContainer.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.clip_contents = true
	var felt: StyleBox = hud.plush("felt")
	felt.set("radius",24)
	felt.content_margin_left = 22
	felt.content_margin_right = 22
	felt.content_margin_top = 16
	felt.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel",felt)
	card.set_meta("ui_safe_insets",Vector4(22,16,22,16))
	add_child(card)

	# Lilac felt header band (drawn under the layout, bleeding into the card padding).
	var band := Control.new()
	band.name = "HeaderBand"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(band)
	band.draw.connect(func():
		var row := card.get_node_or_null("CardLayout/SettingsHeaderRow") as Control
		if row == null: return
		var lilac := StyleBoxFlat.new()
		lilac.bg_color = Color("d6c0ea")
		lilac.corner_radius_top_left = 22
		lilac.corner_radius_top_right = 22
		lilac.anti_aliasing = true
		var rect := Rect2(Vector2(-20,-14),Vector2(band.size.x+40,row.size.y+22))
		band.draw_style_box(lilac,rect)
		var x := rect.position.x+14
		while x < rect.end.x-14:
			band.draw_line(Vector2(x,rect.end.y-5),Vector2(minf(x+7,rect.end.x-14),rect.end.y-5),Color(1,0.97,0.99,0.9),1.6,true)
			x += 12)
	var layout := VBoxContainer.new()
	layout.name = "CardLayout"
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(layout)

	var header := HBoxContainer.new()
	header.name = "SettingsHeaderRow"
	header.custom_minimum_size.y = 52
	header.resized.connect(band.queue_redraw)
	layout.add_child(header)
	var title := Label.new()
	title.name = "SettingsHeader"
	title.text = game.t("settings.title")
	title.add_theme_font_size_override("font_size",_font_size(25))
	title.add_theme_font_override("font",game.locale.heading_font)
	title.add_theme_color_override("font_color",Color("6a3a59"))
	title.add_theme_color_override("font_shadow_color",Color(PINK,0.6))
	title.add_theme_constant_override("shadow_offset_y",3)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = _button("SettingsClose","settings.close",_close)
	hud.controls["ui.close"] = close_button
	close_button.custom_minimum_size = Vector2(100,MIN_TARGET)
	header.add_child(close_button)

	var divider := HSeparator.new()
	divider.name = "HeaderDivider"
	layout.add_child(divider)
	_scroll = ScrollContainer.new()
	_scroll.name = "SettingsScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_scroll)
	groups = GridContainer.new()
	groups.name = "SettingsGroups"
	groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groups.add_theme_constant_override("h_separation",12)
	groups.add_theme_constant_override("v_separation",12)
	_scroll.add_child(groups)
	_build_profile()
	_build_audio()
	_build_preferences()
	var left := VBoxContainer.new()
	left.name = "LeftColumn"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation",12)
	groups.add_child(left)
	groups.move_child(left,0)
	groups.get_node("ProfileGroup").reparent(left)
	groups.get_node("PreferencesGroup").reparent(left)

	var footer_divider := HSeparator.new()
	footer_divider.name = "FooterDivider"
	layout.add_child(footer_divider)
	var footer := HBoxContainer.new()
	footer.name = "SettingsFooter"
	footer.custom_minimum_size.y = 28
	layout.add_child(footer)
	var saved := Label.new()
	_save_note = saved
	saved.name = "SettingsSavedNote"
	saved.text = game.t("settings.autosave")
	saved.add_theme_font_size_override("font_size",_font_size(13))
	saved.add_theme_color_override("font_color",MUTED)
	saved.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(saved)

func _section(id: String, title_key: String) -> VBoxContainer:
	var group := PanelContainer.new()
	group.name = id
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pocket: StyleBox = hud.plush("pocket")
	pocket.content_margin_left = 14
	pocket.content_margin_right = 14
	pocket.content_margin_top = 12
	pocket.content_margin_bottom = 12
	group.add_theme_stylebox_override("panel",pocket)
	groups.add_child(group)
	var body := VBoxContainer.new()
	body.name = "Content"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_child(body)
	var heading := Label.new()
	heading.name = "GroupTitle"
	heading.text = game.t(title_key)
	heading.add_theme_font_size_override("font_size",_font_size(19))
	heading.add_theme_font_override("font",game.locale.heading_font)
	heading.add_theme_color_override("font_color",FOCUS)
	body.add_child(heading)
	return body

func _build_profile() -> void:
	var body := _section("ProfileGroup","settings.profile")
	var name_label := _label("ProfileNameLabel","ui.name",15)
	body.add_child(name_label)
	var name_input := UsernameInput.new(game)
	name_input.name = "username_input"
	name_input.custom_minimum_size.y = MIN_TARGET
	body.add_child(name_input)
	var language_row := HBoxContainer.new()
	language_row.name = "LanguageRow"
	body.add_child(language_row)
	var language_label := _label("LanguageLabel","ui.language",15)
	language_label.custom_minimum_size.x = 90
	language_row.add_child(language_label)
	var select := OptionButton.new()
	select.name = "LanguageSelect"
	select.tooltip_text = game.t("ui.language")
	select.custom_minimum_size = Vector2(120,MIN_TARGET)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.add_item(game.t("ui.english"))
	select.add_item(game.t("ui.chinese"))
	select.selected = 1 if game.locale.locale == "zh_CN" else 0
	select.item_selected.connect(func(index: int):
		game.audio.play_ui("select")
		game.setting("locale","zh_CN" if index == 1 else "en"))
	select.pressed.connect(func(): game.audio.play_ui("open"))
	select.focus_entered.connect(func(): game.audio.play_ui("focus"))
	select.mouse_entered.connect(func(): game.audio.play_ui("hover"))
	language_row.add_child(select)

func _build_audio() -> void:
	var body := _section("AudioGroup","settings.audio")
	body.add_child(_toggle("MasterMute","ui.muted","muted",bool(game.settings.values.muted)))
	body.add_child(_toggle("MusicEnabled","ui.music_enabled","music_enabled",bool(game.settings.values.music_enabled)))
	body.add_child(_toggle("SfxEnabled","ui.sfx_enabled","sfx_enabled",bool(game.settings.values.sfx_enabled)))
	for bus in ["master","music","sfx","ui"]:
		_volume_row(body,bus)

func _build_preferences() -> void:
	var body := _section("PreferencesGroup","settings.preferences")
	body.add_child(_toggle("ReducedMotion","ui.reduced_motion","reduced_motion",bool(game.settings.values.reduced_motion)))

func _label(id: String, key: String, size := 16) -> Label:
	var label := Label.new()
	label.name = id
	label.text = game.t(key)
	label.tooltip_text = label.text
	label.add_theme_font_size_override("font_size",_font_size(size))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _toggle(id: String, key: String, setting_key: String, value: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = id
	toggle.text = game.t(key)
	toggle.tooltip_text = toggle.text
	toggle.button_pressed = value
	toggle.custom_minimum_size.y = MIN_TARGET
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toggle.toggled.connect(func(enabled: bool):
		game.audio.play_ui("toggle")
		game.setting(setting_key,enabled))
	toggle.focus_entered.connect(func(): game.audio.play_ui("focus"))
	toggle.mouse_entered.connect(func(): game.audio.play_ui("hover"))
	return toggle

func _volume_row(parent: Node, bus: String) -> void:
	var row := HBoxContainer.new()
	row.name = "VolumeRow_"+bus
	row.custom_minimum_size.y = MIN_TARGET
	parent.add_child(row)
	var label := _label("VolumeLabel_"+bus,"ui."+bus,14)
	label.custom_minimum_size.x = 90
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = "Volume_"+bus
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(game.settings.values[bus])*100.0
	slider.custom_minimum_size = Vector2(100,MIN_TARGET)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = label.text
	row.add_child(slider)
	var number := Label.new()
	number.name = "VolumeValue_"+bus
	number.custom_minimum_size = Vector2(44,MIN_TARGET)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size",_font_size(14))
	number.text = game.t("ui.percent",{"value":int(slider.value)})
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(number)
	slider.value_changed.connect(func(value: float):
		game.setting(bus,value/100.0)
		game.audio.play_ui("select")
		number.text = game.t("ui.percent",{"value":int(value)}))
	slider.focus_entered.connect(func(): game.audio.play_ui("focus"))

func _button(id: String, key: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = game.t(key)
	button.tooltip_text = button.text
	button.custom_minimum_size.y = MIN_TARGET
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func():
		button.grab_focus()
		game.audio.ensure_music_playing()
		game.audio.play_ui("confirm")
		action.call())
	button.focus_entered.connect(func(): game.audio.play_ui("focus"))
	button.mouse_entered.connect(func(): game.audio.play_ui("hover"))
	return button

func _safe_rect() -> Rect2:
	var viewport := get_viewport_rect().size
	var insets: Vector4 = game.device.safe_insets
	return Rect2(
		Vector2(insets.x+SAFE_MARGIN,insets.y+SAFE_MARGIN),
		Vector2(viewport.x-insets.x-insets.z-SAFE_MARGIN*2,viewport.y-insets.y-insets.w-SAFE_MARGIN*2).max(Vector2.ONE)
	)

func _layout_card() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(card): return
	var available := _safe_rect()
	# Panel borders consume horizontal space, so reserve them before assigning its outer size.
	var panel_border := 2.0
	var desired := Vector2(minf(DESKTOP_CARD.x,available.size.x-panel_border*2),minf(DESKTOP_CARD.y,available.size.y-panel_border*2)).max(Vector2.ONE)
	var narrow := desired.x < 680
	groups.columns = 1 if narrow else 2
	_apply_compact_row_metrics(narrow)
	card.size = desired
	card.position = available.get_center()-desired*0.5

func _apply_compact_row_metrics(narrow: bool) -> void:
	# A one-column phone card cannot retain desktop label and slider minimums.
	# Preserve the 44 px hit area while allowing controls to share the narrow row.
	var label_width := 68.0 if narrow else 118.0
	var slider_width := 50.0 if narrow else 100.0
	var value_width := 40.0 if narrow else 44.0
	var language_width := 72.0 if narrow else 90.0
	var select_width := 80.0 if narrow else 120.0
	for bus in ["master","music","sfx","ui"]:
		var label := get_node_or_null("Card/CardLayout/SettingsScroll/SettingsGroups/AudioGroup/Content/VolumeRow_"+bus+"/VolumeLabel_"+bus) as Label
		var slider := get_node_or_null("Card/CardLayout/SettingsScroll/SettingsGroups/AudioGroup/Content/VolumeRow_"+bus+"/Volume_"+bus) as HSlider
		var value := get_node_or_null("Card/CardLayout/SettingsScroll/SettingsGroups/AudioGroup/Content/VolumeRow_"+bus+"/VolumeValue_"+bus) as Label
		if label != null: label.custom_minimum_size.x = label_width
		if slider != null: slider.custom_minimum_size.x = slider_width
		if value != null: value.custom_minimum_size.x = value_width
	var language_label := get_node_or_null("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/ProfileGroup/Content/LanguageRow/LanguageLabel") as Label
	var language_select := get_node_or_null("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/ProfileGroup/Content/LanguageRow/LanguageSelect") as OptionButton
	if language_label != null: language_label.custom_minimum_size.x = language_width
	if language_select != null: language_select.custom_minimum_size.x = select_width
	if close_button != null: close_button.custom_minimum_size.x = 82.0 if narrow else 100.0

func _close() -> void:
	game.close_modal()

func _process(_delta: float) -> void:
	if game == null or _save_note == null or _last_saved == game.settings.saved: return
	_last_saved = game.settings.saved
	_save_note.text = game.t("settings.autosave" if game.settings.saved else "settings.save_failed")
