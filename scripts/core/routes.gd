extends RefCounted
## Sole authority for routes and nested modal return state.
signal changed
var route := "title"
var stack: Array[Dictionary] = []

func frozen() -> bool:
    return route != "gameplay" or not stack.is_empty()

func go(next: String) -> void:
    stack.clear()
    route = next
    changed.emit()

func open(kind: String, focus: Control = null) -> void:
    stack.append({"kind": kind, "focus": weakref(focus) if is_instance_valid(focus) else null})
    changed.emit()

func close() -> void:
    if stack.is_empty(): return
    var previous: Dictionary = stack.pop_back()
    changed.emit()
    var reference = previous.focus
    if reference != null and is_instance_valid(reference.get_ref()):
        call_deferred("_restore_focus",reference)

func modal() -> String:
    return "" if stack.is_empty() else String(stack.back().kind)

func _restore_focus(reference: WeakRef) -> void:
    var control = reference.get_ref()
    if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
        control.grab_focus()
