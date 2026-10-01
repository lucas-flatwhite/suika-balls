extends RefCounted
## 공 10단계 설정 파일 — 이름·크기·점수·물리값·색을 이 파일 하나에서 고칩니다.
##
## diameter: 용기 내부 폭(W) 대비 지름 비율. 단계가 오를수록 반드시 커져야 합니다.
## score:    이 공이 합체로 새로 생겼을 때 얻는 점수.
## restitution / density / friction / air: Matter.js 기준 출발값.
##   Godot 물리로 옮길 때는 아래 PHYSICS_* 상수로 환산합니다.
## colors:   그리기용 대표 색(무늬 색은 scripts/ball_art.gd 에서 사용).

const BALLS := [
	{"key":"pingpong",   "name":"탁구공",   "diameter":0.08, "score":1,  "restitution":0.70, "density":0.0005, "friction":0.02, "air":0.01,
	 "colors":[Color("ff8f2e"), Color("ffd2a3")]},
	{"key":"golf",       "name":"골프공",   "diameter":0.10, "score":3,  "restitution":0.45, "density":0.0030, "friction":0.05, "air":0.01,
	 "colors":[Color("fbfbf6"), Color("cfd3d6")]},
	{"key":"tennis",     "name":"테니스공", "diameter":0.13, "score":6,  "restitution":0.60, "density":0.0012, "friction":0.30, "air":0.01,
	 "colors":[Color("d4ec2c"), Color("ffffff")]},
	{"key":"baseball",   "name":"야구공",   "diameter":0.16, "score":10, "restitution":0.30, "density":0.0020, "friction":0.25, "air":0.01,
	 "colors":[Color("fbf8ef"), Color("d8322f")]},
	{"key":"softball",   "name":"소프트볼", "diameter":0.20, "score":15, "restitution":0.25, "density":0.0018, "friction":0.25, "air":0.01,
	 "colors":[Color("f3f22b"), Color("d42a2a")]},
	{"key":"volleyball", "name":"배구공",   "diameter":0.25, "score":21, "restitution":0.45, "density":0.0008, "friction":0.15, "air":0.01,
	 "colors":[Color("fdfdf8"), Color("2ab3b8"), Color("ff7f63")]},
	{"key":"soccer",     "name":"축구공",   "diameter":0.30, "score":28, "restitution":0.40, "density":0.0010, "friction":0.20, "air":0.01,
	 "colors":[Color("fbfbfb"), Color("1f2326")]},
	{"key":"basketball", "name":"농구공",   "diameter":0.36, "score":36, "restitution":0.50, "density":0.0012, "friction":0.50, "air":0.01,
	 "colors":[Color("ec7322"), Color("2a1a12")]},
	{"key":"gymball",    "name":"짐볼",     "diameter":0.44, "score":45, "restitution":0.35, "density":0.0004, "friction":0.60, "air":0.01,
	 "colors":[Color("9b5cf6"), Color("e7d8ff")]},
	{"key":"beachball",  "name":"비치볼",   "diameter":0.54, "score":55, "restitution":0.30, "density":0.0002, "friction":0.10, "air":0.03,
	 "colors":[Color("ef3e4a"), Color("ffffff"), Color("2f7fe0"), Color("ffc935"), Color("2fbf71")]},
]

## 마지막 단계(비치볼) 2개가 합쳐질 때의 보너스.
const FINAL_BONUS := 100
## 떨어뜨릴 공 후보(1~5단계)와 가중치 — 작은 공이 조금 더 자주 나옵니다.
const DROP_WEIGHTS := [30, 25, 20, 15, 10]

## 용기 내부 폭(월드 단위)과 세로 비율(가로:세로 = 1:1.3).
const CONTAINER_WIDTH := 600.0
const CONTAINER_RATIO := 1.3

## Matter.js 출발값 → Godot 환산.
## Godot은 두 물체의 반발력을 더하므로(최대 1) 공 하나에는 절반을 줍니다.
const PHYSICS_BOUNCE_SHARE := 0.5
## 벽·바닥의 반발 몫. 공의 몫과 더해져 실제 반발이 됩니다.
const PHYSICS_WALL_BOUNCE := 0.18
## 질량 = 밀도 × 면적(월드 단위²) × 이 계수.
const PHYSICS_MASS_SCALE := 1.0
## frictionAir(1스텝당 감속 비율, 60Hz) → 초당 감쇠.
const MATTER_STEPS_PER_SECOND := 60.0

static func count() -> int:
	return BALLS.size()

static func last_tier() -> int:
	return BALLS.size() - 1

static func ball(tier: int) -> Dictionary:
	return BALLS[clampi(tier, 0, BALLS.size() - 1)]

static func name_of(tier: int) -> String:
	return String(ball(tier).name)

static func radius(tier: int) -> float:
	return float(ball(tier).diameter) * CONTAINER_WIDTH * 0.5

static func score_of(tier: int) -> int:
	return int(ball(tier).score)

static func main_color(tier: int) -> Color:
	return ball(tier).colors[0]

static func mass_of(tier: int) -> float:
	var r := radius(tier)
	return maxf(0.05, float(ball(tier).density) * PI * r * r * PHYSICS_MASS_SCALE)

static func bounce_of(tier: int) -> float:
	return float(ball(tier).restitution) * PHYSICS_BOUNCE_SHARE

static func friction_of(tier: int) -> float:
	return float(ball(tier).friction)

static func linear_damp_of(tier: int) -> float:
	var air := clampf(float(ball(tier).air), 0.0, 0.5)
	return -log(1.0 - air) * MATTER_STEPS_PER_SECOND

## 설정이 규칙을 지키는지 검사합니다(크기 단조 증가 등).
static func validate() -> bool:
	if BALLS.size() != 10 or DROP_WEIGHTS.size() > BALLS.size(): return false
	var previous := 0.0
	for record in BALLS:
		for key in ["key","name","diameter","score","restitution","density","friction","air","colors"]:
			if not record.has(key): return false
		var d := float(record.diameter)
		if d <= previous or d <= 0.0 or d >= 1.0: return false
		previous = d
	return true
