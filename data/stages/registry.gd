extends RefCounted
## 시작 프리셋. 솔로는 빈 용기에서 무한 진행(seed 0 = 매 판 새 무작위).
const STAGES := [
    {"id":"beach", "name_key":"stage.beach", "target":9, "time_limit":0.0, "drop_mode":"goal_random",
     "initial":[], "seed":0}
]
static func validate(stage: Dictionary) -> bool:
    for key in ["id","name_key","initial","seed"]:
        if not stage.has(key): return false
    if not stage.id is String or stage.id.is_empty() or not stage.name_key is String: return false
    if not stage.initial is Array or stage.initial.size() > 16 or not stage.seed is int: return false
    for ball in stage.initial:
        if not ball is Dictionary: return false
        for key in ["tier","x","y"]:
            if not ball.has(key): return false
        if not ball.tier is int or ball.tier < 0 or ball.tier > 9: return false
    return true
