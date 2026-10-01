extends "res://scripts/manus/preview/tuning_transport.gd"

func store() -> Variant:
	var scene := get_tree().current_scene
	return scene.get("tweaks") if scene != null else null

func settings() -> Array:
	return store().descriptors

func requested(setting: Dictionary) -> Variant:
	return store().requested[setting.id]

func active(setting: Dictionary) -> Variant:
	return store().active[setting.id]

func commit(patch: Dictionary) -> bool:
	return store().apply_preview_patch(patch)

func translate(value: String) -> String:
	var scene := get_tree().current_scene
	return str(scene.call("t",value)) if scene != null and scene.has_method("t") and not value.is_empty() else value

func control_for(setting: Dictionary) -> Dictionary:
	var localized := setting.duplicate(true)
	localized["category_key"] = "category." + str(setting.category)
	if not str(setting.get("unit", "")).is_empty(): localized["unit_key"] = str(setting.unit)
	return super.control_for(localized)
