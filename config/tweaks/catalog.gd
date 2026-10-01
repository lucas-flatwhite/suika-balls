extends RefCounted
## Authoritative descriptors. The panel and validation consume this same catalog.
const VERSION := 1
const CATEGORIES := ["UI", "GAMEPLAY", "AUDIO", "PLAYER", "ENEMIES", "ENVIRONMENT"]

static func descriptors() -> Array[Dictionary]:
    return [
        d("ui.hud.opacity", "UI", "float", 1.0, 0.55, 1.0, 0.05, "LIVE", "COSMETIC"),
        d("ui.text.scale", "UI", "float", 1.0, 0.9, 1.2, 0.05, "LIVE", "COSMETIC"),
        d("ui.score.visible", "UI", "bool", true, 0, 1, 1, "LIVE", "COSMETIC"),
        d("ui.reduced_motion", "UI", "bool", false, 0, 1, 1, "LIVE", "COSMETIC"),
        d("gameplay.score.multiplier", "GAMEPLAY", "float", 1.0, 0.25, 3.0, 0.25, "NEXT_RUN", "SCORE_AFFECTING"),
        d("gameplay.overflow_seconds", "GAMEPLAY", "float", 2.0, 1.0, 5.0, 0.2, "NEXT_RUN", "GAMEPLAY", "seconds"),
        d("audio.master.gain", "AUDIO", "float", 0.0, -24, 0, 1, "LIVE", "COSMETIC", "db"),
        d("audio.music.gain", "AUDIO", "float", 0.0, -24, 0, 1, "LIVE", "COSMETIC", "db"),
        d("audio.sfx.gain", "AUDIO", "float", 0.0, -24, 0, 1, "LIVE", "COSMETIC", "db"),
        d("audio.ui.gain", "AUDIO", "float", 0.0, -24, 0, 1, "LIVE", "COSMETIC", "db"),
        d("player.aim.speed", "PLAYER", "float", 540.0, 240, 900, 30, "NEXT_ACTION", "GAMEPLAY", "speed"),
        d("player.claw.open_seconds", "PLAYER", "float", 0.05, 0.01, 0.31, 0.02, "NEXT_ACTION", "GAMEPLAY", "seconds"),
        d("player.claw.reload_seconds", "PLAYER", "float", 0.45, 0.2, 1.2, 0.05, "NEXT_ACTION", "GAMEPLAY", "seconds"),
        d("player.release.spin", "PLAYER", "float", 0.35, 0, 0.7, 0.05, "NEXT_ACTION", "GAMEPLAY"),
        d("enemies.toy.bounce", "ENEMIES", "float", 1.0, 0.0, 1.5, 0.05, "NEXT_SPAWN", "GAMEPLAY"),
        d("enemies.toy.gravity", "ENEMIES", "float", 1.0, 0.5, 1.5, 0.1, "NEXT_SPAWN", "GAMEPLAY"),
        d("environment.particles", "ENVIRONMENT", "float", 1.0, 0, 1.5, 0.25, "LIVE", "COSMETIC"),
        d("environment.ambient", "ENVIRONMENT", "bool", true, 0, 1, 1, "LIVE", "COSMETIC"),
        d("environment.danger.line", "ENVIRONMENT", "float", 312.0, 270, 400, 2, "NEXT_RUN", "GAMEPLAY", "pixels")
    ]

static func d(id: String, category: String, type: String, default: Variant, low: float, high: float,
        step: float, mode: String, integrity: String, unit := "number") -> Dictionary:
    return {"id":id, "category":category, "type":type, "default":default, "min":low, "max":high,
        "step":step, "options":[], "unit":"unit." + unit, "apply_mode":mode, "integrity":integrity,
        "label_key":"tweak." + id + ".label", "description_key":"tweak." + id + ".description",
        "tags":[category.to_lower()]}
