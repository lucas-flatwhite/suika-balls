extends Control
## Mobile-only composition. State, requests and navigation remain with existing owners.
var hud: Control
var title_key := ""
var close_key := "ui.close"
var close_action: Callable
var body: VBoxContainer
var tabs: HBoxContainer
var footer: VBoxContainer
var scroll: ScrollContainer
var header: HBoxContainer
var close_button: Button

func _ready() -> void:
	name = "MobileSheet"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = hud.CREAM
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	# Lilac felt header band with a stitched hem, echoing the claw machine's padded roof.
	var band := Control.new()
	band.name = "HeaderBand"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(band)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",0)
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset: Vector4 = hud.game.device.safe_insets
	var header_margin := _margin(layout,inset,8,6)
	header = hud.row(header_margin)
	header.name = "SheetHeader"
	var title: Label = hud.display(hud.text_label(header,title_key,24))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_color_override("font_color",Color("6a3a59"))
	header_margin.resized.connect(band.queue_redraw)
	band.draw.connect(func():
		var bottom := header_margin.position.y+header_margin.size.y
		band.draw_rect(Rect2(0,0,band.size.x,bottom+4),Color(0.29,0.16,0.25,0.08))
		band.draw_rect(Rect2(0,0,band.size.x,bottom),Color("d6c0ea"))
		var x := 8.0
		while x < band.size.x-8.0:
			band.draw_line(Vector2(x,bottom-6),Vector2(minf(x+7.0,band.size.x-8.0),bottom-6),Color(1,0.97,0.99,0.9),1.6,true)
			x += 12.0)
	close_button = hud.button(header,close_key,close_action)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.custom_minimum_size.x = 88
	close_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	close_button.add_theme_font_size_override("font_size",15)
	var tab_margin := _margin(layout,Vector4(inset.x,0,inset.z,0),0,0)
	tabs = hud.row(tab_margin)
	tabs.name = "SheetTabs"
	scroll = ScrollContainer.new()
	scroll.name = "SheetScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	scroll.scroll_deadzone = 8
	layout.add_child(scroll)
	var content_margin := _margin(scroll,Vector4(inset.x,0,inset.z,0),8,8)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body = hud.column(content_margin)
	body.name = "SheetBody"
	body.add_theme_constant_override("separation",8)
	# The persistent owner launcher stays available without covering sheet actions.
	var owner_clearance := 56 if hud.game.tweaks.enabled else 0
	var footer_margin := _margin(layout,Vector4(inset.x,0,inset.z,inset.w+owner_clearance),6,8)
	footer = hud.column(footer_margin)
	footer.name = "SheetFooter"
	footer.add_theme_constant_override("separation",6)
	set_meta("scroll_owner",scroll)

func _margin(parent: Node,inset: Vector4,top: int,bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",int(inset.x)+16)
	margin.add_theme_constant_override("margin_right",int(inset.z)+16)
	margin.add_theme_constant_override("margin_top",int(inset.y)+top)
	margin.add_theme_constant_override("margin_bottom",int(inset.w)+bottom)
	parent.add_child(margin)
	return margin
