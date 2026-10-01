extends RefCounted
## Named score events and a copy-on-read final result.
const Balls := preload("res://data/balls.gd")
const LIMIT := 10000000
var total := 0
var multiplier := 1.0
var finalized := false
var _result: Dictionary = {}

func reset(factor := 1.0) -> void:
    total = 0
    finalized = false
    _result.clear()
    multiplier = clampf(factor, 0.25, 3.0)

func award(event: String, tier := 0) -> int:
    if finalized: return 0
    var base := 0
    match event:
        "merge":
            if tier < 1 or tier > Balls.last_tier(): return 0
            base = Balls.score_of(tier)
        "final_bonus": base = Balls.FINAL_BONUS
        _: return 0
    var points := int(round(base * multiplier))
    total = clampi(total + points, 0, LIMIT)
    return points

func finish(metadata: Dictionary) -> Dictionary:
    if not finalized:
        _result = metadata.duplicate(true)
        _result.score = total
        finalized = true
    return _result.duplicate(true)

func result() -> Dictionary:
    return _result.duplicate(true)
