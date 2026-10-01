extends RefCounted
# Body UI: Nunito with Noto Sans SC Chinese at the same weight (subset WOFF2, no system fallback).
const UI_REGULAR := preload("res://assets/template/fonts/ui_regular.tres")
const UI_MEDIUM := preload("res://assets/template/fonts/ui_medium.tres")
const UI_BOLD := preload("res://assets/template/fonts/ui_bold.tres")
# Display faces: logo lockup, and headings / big numbers (Latin -> ZCOOL KuaiLe -> Noto Sans SC).
const TITLE_FONT := preload("res://assets/template/fonts/display/mushies_title.tres")
const HEADING_FONT := preload("res://assets/template/fonts/display/mushies_heading.tres")
const DISPLAY_FONT := preload("res://assets/fonts/jua_display.tres")
var display_font: Font = DISPLAY_FONT
var locale := "ko"
var dictionaries: Dictionary = {}
var font: Font
var medium_font: Font
var bold_font: Font
var title_font: Font = TITLE_FONT
var heading_font: Font = HEADING_FONT

func _init() -> void:
    # 한국어 단일 언어. 없는 키는 키 이름을 그대로 보여 누락을 드러냅니다.
    dictionaries.ko = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ko.json"))
    TranslationServer.set_locale(locale)
    font = UI_REGULAR
    medium_font = UI_MEDIUM
    bold_font = UI_BOLD

func font_for_weight(weight := 400) -> Font:
    if weight >= 600: return bold_font
    if weight >= 500: return medium_font
    return font

func t(key: String, placeholders: Dictionary = {}) -> String:
    var text: String = dictionaries.ko.get(key, key)
    for name in placeholders:
        text = text.replace("{" + String(name) + "}", str(placeholders[name]))
    return text
