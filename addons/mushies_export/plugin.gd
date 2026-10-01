@tool
extends EditorPlugin

class ExportChannels extends EditorExportPlugin:
    func _get_name() -> String:
        return "MushiesExportChannels"

    func _get_export_features(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
        if platform.get_os_name() != "Web":
            return PackedStringArray()
        return PackedStringArray(["owner_preview" if debug else "checkpoint"])

var export_channels := ExportChannels.new()

func _enter_tree() -> void:
    add_export_plugin(export_channels)

func _exit_tree() -> void:
    remove_export_plugin(export_channels)
