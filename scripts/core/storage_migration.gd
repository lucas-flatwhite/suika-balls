extends RefCounted
## A display-name change must not discard the previous native game's saves.
const FILES := ["template_settings.json","plushie_leaderboard_v1.json","plushie_tweaks_v1.json"]

static func migrate_rename(destination: String,legacy: String) -> void:
    for name in FILES:
        var target := destination.path_join(name)
        var source := legacy.path_join(name)
        if not FileAccess.file_exists(target) and FileAccess.file_exists(source):
            DirAccess.copy_absolute(source,target)

static func run() -> void:
    if OS.has_feature("web"): return # The browser keeps its existing origin/userfs namespace.
    var current := OS.get_user_data_dir()
    if current.get_file() != "Mushies": return
    # Historical directory alias only: existing installs must retain their saves.
    migrate_rename(current,current.get_base_dir().path_join("Plushie Pile"))
