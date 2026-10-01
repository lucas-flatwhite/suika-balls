extends RefCounted
const PATH := "user://plushie_leaderboard_v1.json"
const LIMIT := 10
var path := PATH
var rows: Array[Dictionary] = []
var saved := true

func valid(row: Variant) -> bool:
    if not row is Dictionary: return false
    for key in ["run_id","name","score","stage","outcome","timestamp","duration","config","eligible"]:
        if not row.has(key): return false
    for key in ["run_id","name","stage","config"]:
        if not row[key] is String or row[key].length() > 200: return false
    for key in ["score","duration","timestamp"]:
        if not (row[key] is int or row[key] is float) or not is_finite(float(row[key])) or row[key] < 0: return false
    return row.outcome in ["victory","defeat"] and row.eligible is bool and row.score <= 10000000 and row.name.length() <= 20

func load_data() -> void:
    rows.clear()
    if not FileAccess.file_exists(path): return
    var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not raw is Dictionary or raw.get("version") != 1 or not raw.get("rows") is Array: return
    var seen := {}
    for row in raw.rows:
        if valid(row) and not seen.has(row.run_id):
            rows.append(row.duplicate(true))
            seen[row.run_id] = true
    _sort()

func record(row: Dictionary) -> bool:
    if not valid(row) or row.eligible != true: return false
    for existing in rows:
        if existing.run_id == row.run_id: return false
    rows.append(row.duplicate(true))
    _sort()
    var file := FileAccess.open(path, FileAccess.WRITE)
    saved = file != null
    if saved: file.store_string(JSON.stringify({"version":1,"rows":rows}))
    return saved

func _sort() -> void:
    rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if a.score != b.score: return a.score > b.score
        if a.duration != b.duration: return a.duration < b.duration
        if a.timestamp != b.timestamp: return a.timestamp < b.timestamp
        return a.run_id < b.run_id)
    if rows.size() > LIMIT: rows.resize(LIMIT)

func rename_record(run_id: String, new_name: String) -> bool:
    if new_name.is_empty() or new_name.length() > 20: return false
    for row in rows:
        if row.run_id != run_id: continue
        if row.name == new_name: return true
        row.name = new_name
        var file := FileAccess.open(path,FileAccess.WRITE)
        saved = file != null
        if saved: file.store_string(JSON.stringify({"version":1,"rows":rows}))
        return saved
    return false
