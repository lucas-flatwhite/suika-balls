extends RefCounted
## 최고 점수: 브라우저에 저장되어 새로고침 후에도 유지됩니다.
## Web은 localStorage와 user://(IndexedDB) 둘 다에 기록하고 큰 값을 씁니다.
const PATH := "user://beach_best_score.json"
const STORAGE_KEY := "beachball_merge_best"
var path := PATH
var value := 0

func load_data() -> void:
    value = 0
    if FileAccess.file_exists(path):
        var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
        if raw is Dictionary and (raw.get("best") is int or raw.get("best") is float):
            value = maxi(0, int(raw.best))
    if OS.has_feature("web"):
        var stored = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||'0'}catch(e){return '0'}})()" % STORAGE_KEY, true)
        if stored is String and stored.is_valid_int():
            value = maxi(value, int(stored))

## 새 기록이면 저장하고 true.
func submit(score: int) -> bool:
    if score <= value: return false
    value = score
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"best": value}))
        file.close()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("try{localStorage.setItem('%s','%d')}catch(e){}" % [STORAGE_KEY, value], true)
    return true
