extends SceneTree

var failures: Array[String] = []
var body_script: Script
var bomb_script: Script

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    body_script = load("res://scripts/plushie_body.gd")
    bomb_script = load("res://scripts/bomb_plushie.gd")
    for tier in range(12):
        for angle in [0.0,0.55,PI/2.0]:
            await _floor_case(tier,angle)
    _replacement_cases()
    await _stack_case()
    await _air_case()
    if failures.is_empty():
        print("PASS: shared-silhouette plushie/bomb contacts preserve floor, rotation and stacks; airborne/held squash and physical tumble remain.")
    quit(0 if failures.is_empty() else 1)

func _body(tier: int) -> RigidBody2D:
    var body = (bomb_script if tier == 11 else body_script).new()
    body.configure(0 if tier == 11 else tier,null)
    body.lock_rotation = true
    body.physics_material_override.bounce = 0.0
    return body

func _floor(arena: Node2D) -> void:
    var floor := StaticBody2D.new()
    floor.position = Vector2(400,620)
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(800,40)
    collision.shape = shape
    floor.add_child(collision)
    arena.add_child(floor)

func _support(body: RigidBody2D,angle: float) -> float:
    var bottom := -INF
    for point in body.outline: bottom = maxf(bottom,point.rotated(angle).y)
    return bottom

func _floor_case(tier: int,angle: float) -> void:
    var arena := Node2D.new()
    root.add_child(arena)
    _floor(arena)
    var body := _body(tier)
    body.rotation = angle
    body.position = Vector2(400,599.5-_support(body,angle))
    arena.add_child(body)
    for frame in 60: await physics_frame
    _check(body.has_surface_contact,"no floor contact for tier %d angle %.2f" % [tier,angle])
    _check(absf(body.rotation-angle) < 0.001,"grounding snapped a rotated body upright")
    body.impact(1.0)
    body._process(0.016)
    _check(body.visual_scale.is_equal_approx(Vector2.ONE),"contact squash leaves collider on tier %d" % tier)
    _check(body.scale.is_equal_approx(Vector2.ONE),"grounding scales the physics body")
    _check(body.piece_count > 0,"silhouette did not create compound collisions")
    _check(body.piece_count <= 64,"alpha detail creates too many physics pieces for a browser pile")
    arena.queue_free()
    await process_frame

func _stack_case() -> void:
    var arena := Node2D.new()
    root.add_child(arena)
    _floor(arena)
    var lower := _body(10)
    lower.position = Vector2(400,599.5-_support(lower,0.0))
    arena.add_child(lower)
    var upper := _body(0)
    upper.position = Vector2(400,lower.position.y-220)
    arena.add_child(upper)
    for frame in 240: await physics_frame
    _check(lower.has_surface_contact and upper.has_surface_contact,"stack did not settle in mutual contact")
    for body in [lower,upper]:
        body.impact(1.0)
        body._process(0.016)
        _check(body.visual_scale.is_equal_approx(Vector2.ONE),"cosmetic squash opens a gap in a supported stack")
    arena.queue_free()
    await process_frame

func _air_case() -> void:
    var body := _body(0)
    body.lock_rotation = false
    body.position = Vector2(400,-400)
    body.angular_velocity = 1.2
    root.add_child(body)
    body.impact(0.8)
    body._process(0.016)
    _check(not body.visual_scale.is_equal_approx(Vector2.ONE),"airborne squash was disabled")
    for frame in 20: await physics_frame
    _check(not body.has_surface_contact and absf(body.rotation) > 0.05,"airborne rotation was snapped or frozen")
    _check(body.position.y > -400,"airborne gravity was disabled")
    body.held = true
    body._process(0.016)
    _check(not body.visual_scale.is_equal_approx(Vector2.ONE),"held compression was disabled")
    body.queue_free()
    await process_frame

func _replacement_cases() -> void:
    var helper = load("res://scripts/sprite_silhouette.gd")
    var padded := Image.create(80,96,false,Image.FORMAT_RGBA8)
    padded.fill(Color.TRANSPARENT)
    padded.fill_rect(Rect2i(13,7,32,64),Color.WHITE)
    var geometry: Dictionary = helper.geometry(ImageTexture.create_from_image(padded),Vector2(80,96))
    _check(geometry.error.is_empty(),"padded replacement failed silhouette generation")
    var bounds := Rect2(geometry.outline[0],Vector2.ZERO)
    for point in geometry.outline: bounds = bounds.expand(point)
    _check(bounds.is_equal_approx(Rect2(-27,-41,32,64)),"transparent padding moves replacement collider edges")
    var empty := Image.create(80,96,false,Image.FORMAT_RGBA8)
    empty.fill(Color.TRANSPARENT)
    for invalid in [null,ImageTexture.create_from_image(empty)]:
        var fallback: Dictionary = helper.geometry(invalid,Vector2(80,96))
        _check(not fallback.error.is_empty(),"invalid replacement lacks a clear diagnostic")
        _check(fallback.outline.size() == 4 and fallback.pieces.size() == 1,"invalid replacement silently loses collision")

func _check(condition: bool,message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("GROUNDING: "+message)
