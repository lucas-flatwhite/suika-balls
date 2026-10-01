extends SceneTree

var failures: Array[String] = []
var body_script: Script
var bomb_script: Script
var output := ""
var samples := 0

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Use a real renderer or Xvfb for sprite grounding.")
        quit(1)
        return
    body_script = load("res://scripts/plushie_body.gd")
    bomb_script = load("res://scripts/bomb_plushie.gd")
    output = OS.get_environment("GAME_CAPTURE_DIR")
    if output.is_empty(): output = "user://grounding-captures"
    DirAccess.make_dir_recursive_absolute(output)
    for tier in range(12):
        for angle in [0.0,0.55,PI/2.0]:
            await _floor_case(tier,angle)
    await _stack_case()
    if failures.is_empty():
        print("PASS: %d native alpha-bound contact samples cover every plushie/bomb, rotated floor contact, impact and visible stack stability." % samples)
    quit(0 if failures.is_empty() else 1)

func _viewport() -> SubViewport:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(600,600)
    viewport.world_2d = World2D.new()
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var floor := StaticBody2D.new()
    floor.position = Vector2(300,470)
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(600,40)
    collision.shape = shape
    floor.add_child(collision)
    viewport.add_child(floor)
    return viewport

func _body(tier: int) -> RigidBody2D:
    var body = (bomb_script if tier == 11 else body_script).new()
    body.configure(0 if tier == 11 else tier,null)
    body.lock_rotation = true
    body.physics_material_override.bounce = 0.0
    return body

func _support(body: RigidBody2D,angle: float) -> float:
    var bottom := -INF
    for point in body.outline: bottom = maxf(bottom,point.rotated(angle).y)
    return bottom

func _capture(viewport: SubViewport) -> Image:
    await process_frame
    RenderingServer.force_draw(false)
    return viewport.get_texture().get_image()

func _floor_case(tier: int,angle: float) -> void:
    var viewport := _viewport()
    var body := _body(tier)
    body.rotation = angle
    body.position = Vector2(300,449.5-_support(body,angle))
    viewport.add_child(body)
    for frame in 60: await physics_frame
    _check(body.has_surface_contact,"fixture not touching floor")
    body.freeze = true
    body.set_process(false)
    for strength in [0.0,1.0]:
        body.impact(strength)
        body._process(0.016)
        var image := await _capture(viewport)
        var visible := image.get_used_rect()
        var label := "tier-%02d-angle-%.2f-impact-%.1f" % [tier,angle,strength]
        _check(visible.has_area(),"invisible "+label)
        _check(absf(float(visible.end.y)-450.0) <= 1.0,"rendered feet leave support for %s: alpha bottom %s" % [label,visible.end.y])
        var buried := 0
        for y in range(451,image.get_height()):
            for x in image.get_width():
                if image.get_pixel(x,y).a > 0.1: buried += 1
        _check(buried == 0,"solid sprite pixels buried under floor "+label)
        _check(image.save_png(output.path_join("puzzle-"+label+".png")) == OK,"cannot save "+label)
        samples += 1
    viewport.queue_free()
    await process_frame

func _stack_case() -> void:
    var viewport := _viewport()
    var lower := _body(10)
    lower.position = Vector2(300,449.5-_support(lower,0.0))
    viewport.add_child(lower)
    var upper := _body(0)
    upper.position = Vector2(300,lower.position.y-220)
    viewport.add_child(upper)
    for frame in 240: await physics_frame
    _check(lower.has_surface_contact and upper.has_surface_contact,"native stack did not settle")
    for body in [lower,upper]:
        body.freeze = true
        body.set_process(false)
        body.squish = 0.0
        body.squish_velocity = 0.0
        body._process(0.016)
    var before := await _capture(viewport)
    for body in [lower,upper]:
        body.impact(1.0)
        body._process(0.016)
    var after := await _capture(viewport)
    _check(before.get_data() == after.get_data(),"contact impact visibly separates or penetrates the stack")
    after.save_png(output.path_join("puzzle-stack-impact.png"))
    upper.visible = false
    var lower_image := await _capture(viewport)
    upper.visible = true
    lower.visible = false
    var upper_image := await _capture(viewport)
    var contact_pixels := 0
    var overlapping_pixels := 0
    for y in range(2,598):
        for x in range(2,598):
            if upper_image.get_pixel(x,y).a < 0.1: continue
            if lower_image.get_pixel(x,y).a > 0.1: overlapping_pixels += 1
            var near_lower := false
            for dy in range(-2,3):
                for dx in range(-2,3):
                    if lower_image.get_pixel(x+dx,y+dy).a > 0.1: near_lower = true
            if near_lower: contact_pixels += 1
    _check(contact_pixels > 0,"visible stacked silhouettes do not touch within raster tolerance")
    _check(overlapping_pixels <= 20,"visible stacked silhouettes interpenetrate: "+str(overlapping_pixels))
    samples += 1
    viewport.queue_free()
    await process_frame

func _check(condition: bool,message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("GROUNDING_RENDER: "+message)
