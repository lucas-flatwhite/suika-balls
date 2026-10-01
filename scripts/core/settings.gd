extends RefCounted
const PATH := "user://template_settings.json"
const DEFAULTS := {"locale":"ko", "name":"", "muted":false, "reduced_motion":false,
    "music_enabled":true, "sfx_enabled":true,
    "master":0.85, "music":0.8, "sfx":0.85, "ui":0.8}
var values: Dictionary = DEFAULTS.duplicate()
var path := PATH
var saved := true
## True only when the settings file carries a valid language choice.
var locale_saved := false

## 첫 실행 언어: 저장된 선택이 없으면 OS/브라우저 언어가 ko*이면 한국어, 그 밖에는 영어.
static func detect_locale(os_locale: String) -> String:
    return "ko" if os_locale.to_lower().begins_with("ko") else "en"

func load_data() -> void:
    locale_saved = false
    if not FileAccess.file_exists(path): return
    var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not raw is Dictionary: return
    for key in DEFAULTS:
        if not raw.has(key): continue
        if set_value(key, raw[key], false) and key == "locale": locale_saved = true

## Without a saved choice, follow the OS locale (on Web: the browser language).
func apply_detected_locale(os_locale: String) -> void:
    if not locale_saved: values.locale = detect_locale(os_locale)

func set_value(key: String, value: Variant, persist := true) -> bool:
    if not DEFAULTS.has(key): return false
    if key == "locale":
        if not value in ["ko", "en"]: return false
    elif key == "name":
        if not value is String: return false
        value = value.strip_edges().replace("\n", " ").left(20)
    elif DEFAULTS[key] is bool:
        if not value is bool: return false
    else:
        if not (value is float or value is int) or not is_finite(float(value)): return false
        value = clampf(float(value), 0.0, 1.0)
    values[key] = value
    if persist and key == "locale": locale_saved = true
    if persist:
        var file := FileAccess.open(path, FileAccess.WRITE)
        saved = file != null
        if not saved: return false
        file.store_string(JSON.stringify(values))
        saved = file.get_error() == OK
        if not saved: return false
    return true
