extends RefCounted
## 한 판의 규칙 상태: 무작위 투하(1~5단계 가중치), 합체 점수, 비치볼 보너스, 종료.
## 솔로는 시간 제한 없이 데드라인 게임오버까지 계속됩니다.
const Score := preload("res://scripts/score/score_service.gd")
const Stages := preload("res://data/stages/registry.gd")
const Balls := preload("res://data/balls.gd")
const GOAL_TIME_BONUS_SECONDS := 0.0
const RESCUE_DISTANCE := 0.0
var stage: Dictionary = {}
var score := Score.new()
var elapsed := 0.0
var drops := 0
var merges := 0
## 이번 판에 판 위에 나온 가장 큰 단계(0부터).
var highest := 0
var goal_tier := 1
var goals_reached := 0
var beach_bonuses := 0
var outcome := ""
var reason := ""
var run_id := ""
var rng := RandomNumberGenerator.new()
var _drop_rng := RandomNumberGenerator.new()
var _drop_queue: Array[int] = []

func start(definition: Dictionary, multiplier := 1.0) -> bool:
    if not Stages.validate(definition): return false
    stage = definition.duplicate(true)
    elapsed = 0.0
    drops = 0
    merges = 0
    highest = 0
    goal_tier = 1
    goals_reached = 0
    beach_bonuses = 0
    outcome = ""
    reason = ""
    run_id = "%d-%d" % [Time.get_unix_time_from_system() * 1000, Time.get_ticks_usec()]
    var seed_value := int(stage.seed)
    if seed_value == 0:
        var fresh := RandomNumberGenerator.new()
        fresh.randomize()
        seed_value = fresh.randi_range(1, 2147483646)
    rng.seed = seed_value
    _drop_rng.seed = seed_value ^ 0x44524F50
    _drop_queue.clear()
    for index in range(2): _drop_queue.append(_roll_drop())
    score.reset(multiplier)
    return true

func tick(delta: float) -> void:
    if outcome != "": return
    elapsed += maxf(0, delta)

func time_budget() -> float:
    return float(stage.get("time_limit", 0.0))

func remaining_time() -> float:
    return INF

## 합체로 tier 단계 공이 새로 생김. 얻은 점수를 돌려줍니다.
func merge(tier: int) -> int:
    if outcome != "": return 0
    merges += 1
    note_tier(tier)
    return score.award("merge", tier)

## 마지막 단계 공 2개가 합쳐져 사라짐.
func final_pair() -> int:
    if outcome != "": return 0
    merges += 1
    beach_bonuses += 1
    return score.award("final_bonus")

func note_tier(tier: int) -> void:
    if tier > highest: highest = tier
    if tier >= goal_tier:
        goals_reached = tier
        goal_tier = mini(Balls.last_tier(), tier + 1)

func finish(result: String, why: String) -> void:
    if outcome != "": return
    outcome = result
    reason = why

func next_tier(offset := 0) -> int:
    if stage.is_empty() or _drop_queue.is_empty(): return 0
    return _drop_queue[clampi(offset, 0, _drop_queue.size() - 1)]

func uses_random_drops() -> bool:
    return true

func _roll_drop() -> int:
    var total := 0
    for weight in Balls.DROP_WEIGHTS: total += int(weight)
    var roll := _drop_rng.randi_range(0, maxi(0, total - 1))
    for index in range(Balls.DROP_WEIGHTS.size()):
        roll -= int(Balls.DROP_WEIGHTS[index])
        if roll < 0: return index
    return 0

func record_drop() -> void:
    if not can_drop(): return
    drops += 1
    # Preserve the promised preview; only the newly queued ball is random.
    _drop_queue.pop_front()
    _drop_queue.append(_roll_drop())

func can_drop() -> bool:
    return outcome == "" and not stage.is_empty()
