extends RefCounted
const PATH := "user://template_settings.json"
const DEFAULTS := {"locale":"en", "name":"", "muted":false, "reduced_motion":false,
    "music_enabled":true, "sfx_enabled":true,
    "master":0.85, "music":0.8, "sfx":0.85, "ui":0.8}
var values: Dictionary = DEFAULTS.duplicate()
var path := PATH
var saved := true
## True only when the settings file carries a valid language choice.
var locale_saved := false

## 사이트 전체가 함께 쓰는 언어 저장 키(lucasflatwhite.com의 lucas-flatwhite:locale). Web에서만 읽고 씁니다.
const SITE_LOCALE_KEY := "lucas-flatwhite:locale"
const SUPPORTED_LOCALES := ["ko", "en"]

func load_data() -> void:
    locale_saved = false
    if not FileAccess.file_exists(path): return
    var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not raw is Dictionary: return
    for key in DEFAULTS:
        if not raw.has(key): continue
        if set_value(key, raw[key], false) and key == "locale": locale_saved = true

## 시작 언어: 사이트에서 고른 언어(site_locale) → 이 게임에 저장된 선택 → 영어.
## 브라우저·OS 언어는 따르지 않습니다. 누가 고르기 전까지는 영어로 시작합니다.
func apply_site_locale(site_locale: String) -> void:
    if site_locale in SUPPORTED_LOCALES: values.locale = site_locale
    elif not locale_saved: values.locale = DEFAULTS.locale

func set_value(key: String, value: Variant, persist := true) -> bool:
    if not DEFAULTS.has(key): return false
    if key == "locale":
        if not value in SUPPORTED_LOCALES: return false
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
