extends RefCounted
signal changed
const Catalog := preload("res://config/tweaks/catalog.gd")
var descriptors: Array[Dictionary] = Catalog.descriptors()
var requested: Dictionary = {}
var active: Dictionary = {}
var by_id: Dictionary = {}
var enabled := false
var tainted := false
var running := false

func _init(owner_preview := false) -> void:
    enabled = owner_preview
    for descriptor in descriptors:
        by_id[descriptor.id] = descriptor
        requested[descriptor.id] = descriptor.default
        active[descriptor.id] = descriptor.default

static func owner_build() -> bool:
    return OS.is_debug_build() and not OS.has_feature("release") and not OS.has_feature("checkpoint")

func valid(id: String, value: Variant) -> bool:
    if not by_id.has(id): return false
    var descriptor: Dictionary = by_id[id]
    if descriptor.type == "bool": return value is bool
    if not (value is int or value is float) or not is_finite(float(value)): return false
    if value < descriptor.min or value > descriptor.max: return false
    var ticks: float = (float(value) - float(descriptor.default)) / float(descriptor.step)
    return absf(ticks - roundf(ticks)) < 0.001

func request(id: String, value: Variant) -> bool:
    if not enabled or not valid(id, value): return false
    requested[id] = value
    if by_id[id].apply_mode == "LIVE": apply("LIVE")
    changed.emit()
    return true

func apply(boundary: String) -> void:
    if not enabled: return
    for descriptor in descriptors:
        if descriptor.apply_mode != boundary: continue
        var value: Variant = requested[descriptor.id]
        active[descriptor.id] = value
        if running and descriptor.integrity != "COSMETIC" and value != descriptor.default:
            tainted = true

func begin_run() -> void:
    running = true
    tainted = false
    for boundary in ["LIVE", "NEXT_RUN", "NEXT_ACTION", "NEXT_SPAWN"]: apply(boundary)

func value(id: String) -> Variant:
    return active[id]

func reset(id: String) -> void:
    request(id, by_id[id].default)

func reset_all() -> void:
    if not enabled: return
    for descriptor in descriptors: requested[descriptor.id] = descriptor.default
    apply("LIVE")
    changed.emit()

func marker() -> String:
    var simulation := {}
    for descriptor in descriptors:
        if descriptor.integrity != "COSMETIC": simulation[descriptor.id] = active[descriptor.id]
    return ("tuned-" if tainted else "baseline-") + JSON.stringify(simulation).sha256_text().left(12)

func apply_preview_patch(patch: Dictionary) -> bool:
    if not enabled: return false
    for id: String in patch:
        if not valid(id,patch[id]): return false
    var dirty := false
    for id: String in patch:
        if requested[id] == patch[id]: continue
        requested[id] = patch[id]
        dirty = true
    if dirty:
        apply("LIVE")
        changed.emit()
    return true
