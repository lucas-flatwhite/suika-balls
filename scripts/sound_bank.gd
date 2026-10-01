extends RefCounted

const STREAMS := {
    &"carriage_loop": preload("res://assets/template/audio_v2/runtime/carriage_loop.ogg"),
    &"claw_open": preload("res://assets/template/audio_v2/runtime/claw_open.ogg"),
    &"claw_close": preload("res://assets/template/audio_v2/runtime/claw_close.ogg"),
    &"release_whoosh": preload("res://assets/template/audio_v2/runtime/release_whoosh.ogg"),
    &"impact_soft_a": preload("res://assets/template/audio_v2/runtime/impact_soft_a.ogg"),
    &"impact_soft_b": preload("res://assets/template/audio_v2/runtime/impact_soft_b.ogg"),
    &"impact_heavy": preload("res://assets/template/audio_v2/runtime/impact_heavy.ogg"),
    &"wall_tap": preload("res://assets/template/audio_v2/runtime/wall_tap.ogg"),
    &"merge_small": preload("res://assets/template/audio_v2/runtime/merge_small.ogg"),
    &"merge_large": preload("res://assets/template/audio_v2/runtime/merge_large.ogg"),
    &"chain_bonus": preload("res://assets/template/audio_v2/runtime/chain_bonus.ogg"),
    &"discovery": preload("res://assets/template/audio_v2/runtime/discovery.ogg"),
    &"dragon_arrival": preload("res://assets/template/audio_v2/runtime/dragon_arrival.ogg"),
    &"danger": preload("res://assets/template/audio_v2/runtime/danger.ogg"),
    &"game_over": preload("res://assets/template/audio_v2/runtime/game_over.ogg"),
    &"ui_click": preload("res://assets/template/audio_v2/runtime/ui_click.ogg"),
    &"ui_open": preload("res://assets/template/audio_v2/runtime/ui_open.ogg"),
    &"restart": preload("res://assets/template/audio_v2/runtime/restart.ogg"),
    &"bomb_pop": preload("res://assets/template/audio_v2/runtime/bomb_pop.ogg")
}
const LEVELS := {
    &"carriage_loop": -22.0, &"claw_open": -9.0, &"claw_close": -10.0,
    &"release_whoosh": -15.0, &"impact_soft_a": -11.0, &"impact_soft_b": -11.0,
    &"impact_heavy": -7.0, &"wall_tap": -14.0, &"merge_small": -6.0,
    &"merge_large": -6.0, &"chain_bonus": -11.0, &"discovery": -8.0,
    &"dragon_arrival": -4.0, &"danger": -7.0, &"game_over": -5.0,
    &"ui_click": -10.0, &"ui_open": -10.0, &"restart": -8.0, &"bomb_pop": -6.0
}
const COOLDOWNS := {
    &"claw_open": 0.12, &"claw_close": 0.12, &"release_whoosh": 0.12,
    &"impact_soft_a": 0.12, &"impact_soft_b": 0.12, &"impact_heavy": 0.18,
    &"wall_tap": 0.18, &"merge_small": 0.04, &"merge_large": 0.04,
    &"chain_bonus": 0.45, &"discovery": 0.18, &"dragon_arrival": 0.8,
    &"danger": 1.5, &"game_over": 0.8, &"ui_click": 0.06,
    &"ui_open": 0.10, &"restart": 0.10, &"bomb_pop": 0.08
}
const LOW_PRIORITY := [&"claw_open", &"claw_close", &"release_whoosh", &"impact_soft_a", &"impact_soft_b", &"impact_heavy", &"wall_tap"]
