extends CanvasLayer
## Draw above solo/multiplayer menus and native orientation covers.
var message := "화면 크기가 바뀌어 이번 판이 끝났어요"
var font: Font
var panel: PanelContainer
var label: Label

func _ready() -> void:
    layer = 100
    visible = false
    panel = PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color("7f263e")
    style.border_color = Color("ffc47b")
    style.set_border_width_all(3)
    style.set_corner_radius_all(12)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel",style)
    add_child(panel)
    label = Label.new()
    label.name = "ResizeEndedBanner"
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_override("font",font)
    label.add_theme_color_override("font_color",Color("fff8ed"))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(label)
    get_viewport().size_changed.connect(_layout)
    _layout()

func _layout() -> void:
    var width: float = get_viewport().get_visible_rect().size.x
    panel.position = Vector2(12,12)
    label.add_theme_font_size_override("font_size",clampi(int(width/28.0),20,36))
    panel.size = Vector2(maxf(1,width-24),0)
