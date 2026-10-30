extends Node
## Bind bundled UI fonts after Godot imports the resources.
var _regular: Font
var _theme: Theme

func _enter_tree() -> void:
    _regular = load("res://assets/template/fonts/ui_regular.tres") as Font
    assert(_regular != null, "Bundled UI font failed to import")
    _theme = Theme.new()
    _theme.default_font = _regular
    var medium := load("res://assets/template/fonts/ui_medium.tres") as Font
    var bold := load("res://assets/template/fonts/ui_bold.tres") as Font
    for control_type: String in ["Button", "CheckButton", "CheckBox", "OptionButton", "MenuButton"]:
        _theme.set_font("font", control_type, medium)
    _theme.set_font("normal_font", "RichTextLabel", _regular)
    _theme.set_font("bold_font", "RichTextLabel", bold)
    get_tree().node_added.connect(_bind_node)
    _bind_tree(get_tree().root)

func _bind_tree(node: Node) -> void:
    _bind_node(node)
    for child in node.get_children():
        _bind_tree(child)

func _bind_node(node: Node) -> void:
    if node is Control:
        if node.theme != null:
            if node.theme.default_font == null:
                node.theme = node.theme.duplicate()
                node.theme.default_font = _regular
        elif node.get_parent_control() == null:
            node.theme = _theme
    elif node is Label3D and node.font == null:
        node.font = _regular
