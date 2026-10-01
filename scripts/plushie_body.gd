extends RigidBody2D
class_name PlushieBody
## 한 개의 스포츠 공. 원형 충돌체, data/balls.gd 의 물리값, 코드로 그린 회전 무늬.
## (클래스 이름은 템플릿 호환을 위해 유지합니다.)
const Balls := preload("res://data/balls.gd")
const BallArt := preload("res://scripts/ball_art.gd")

## Settling aid: a resting pile must calm down within 1–2 seconds.
const REST_SPEED := 26.0
const REST_DAMP := 0.86
const POP_SECONDS := 0.22

var tier := 0
var manager: Node
var held := false
var merge_locked := false
var destroy_pending := false
var age := 0.0
var danger_time := 0.0
var radius := 24.0
var render_size := Vector2(48, 48)
var squish_velocity := 0.0
var visual_scale := Vector2.ONE
var halo := 0.0
var pop := 1.0
var has_surface_contact := false
var _impact_cooldown := 0.0
var _last_velocity := Vector2.ZERO
var _shape: CircleShape2D
var _drawn_scale := -1.0
var _drawn_halo := -1.0
var _drawn_rotation := 999.0

static func resources_valid() -> bool:
	return Balls.validate()

func configure(new_tier: int, owner_game: Node) -> void:
	tier = clampi(new_tier, 0, Balls.last_tier())
	manager = owner_game
	radius = Balls.radius(tier)
	render_size = Vector2.ONE * radius * 2.0
	var collider := CollisionShape2D.new()
	collider.name = "BallShape"
	_shape = CircleShape2D.new()
	_shape.radius = radius
	collider.shape = _shape
	add_child(collider)
	mass = Balls.mass_of(tier)
	var gravity := 1.0
	if is_instance_valid(manager): gravity = float(manager.tweaks.value("enemies.toy.gravity"))
	gravity_scale = gravity
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = Balls.linear_damp_of(tier)
	angular_damp = 0.9
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = true
	physics_material_override = PhysicsMaterial.new()
	var bounce_scale := 1.0
	if is_instance_valid(manager): bounce_scale = float(manager.tweaks.value("enemies.toy.bounce"))
	physics_material_override.bounce = clampf(Balls.bounce_of(tier) * bounce_scale, 0.0, 1.0)
	physics_material_override.friction = Balls.friction_of(tier)
	z_index = 3
	queue_redraw()

## Merge spawn: the collider grows with the visual pop instead of exploding.
func start_pop() -> void:
	pop = 0.0
	if _shape: _shape.radius = radius * 0.72

func _ready() -> void:
	body_entered.connect(_on_contact)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var contacts := state.get_contact_count()
	has_surface_contact = contacts > 0
	var delta_v := (state.linear_velocity - _last_velocity).length()
	if contacts > 0 and delta_v > 70.0 and _impact_cooldown <= 0.0:
		var side_wall := false
		for index in range(contacts):
			var other := state.get_contact_collider_object(index) as Node
			if is_instance_valid(other) and (other.is_in_group("cabinet_walls") or other.is_in_group("cabinet_floor")):
				side_wall = true
				break
		impact(minf(delta_v / 700.0, 1.0), side_wall)
	# Calm a resting pile: slow contacts lose energy quickly so stacks never buzz.
	if contacts > 0 and age > 0.35 and pop >= 1.0:
		var speed := state.linear_velocity.length()
		if speed < REST_SPEED:
			state.linear_velocity *= REST_DAMP
			state.angular_velocity *= 0.9
		elif speed < REST_SPEED * 3.0:
			state.linear_velocity *= 0.985
	_last_velocity = state.linear_velocity

func impact(strength: float, wall: bool = false) -> void:
	squish_velocity += clampf(strength, 0.0, 1.0) * 5.0
	_impact_cooldown = 0.12
	if is_instance_valid(manager) and strength > 0.12:
		manager.plushie_impact(strength, tier, wall)

func _physics_process(_delta: float) -> void:
	# Backstop for contacts that began while one ball was merge-locked.
	if held or merge_locked or destroy_pending or not is_instance_valid(manager): return
	if Engine.get_physics_frames() % 6 != get_instance_id() % 6: return
	for other in get_colliding_bodies():
		if other is PlushieBody and other.tier == tier and other.manager == manager:
			manager.request_merge(self, other)
			return

func _process(delta: float) -> void:
	if is_instance_valid(manager) and manager.is_frozen(): return
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	halo = maxf(0.0, halo - delta)
	if pop < 1.0:
		pop = minf(1.0, pop + delta / POP_SECONDS)
		if _shape: _shape.radius = radius * lerpf(0.72, 1.0, ease(pop, 0.5))
	var reduced: bool = is_instance_valid(manager) and manager.reduced_motion()
	var s := 1.0
	if pop < 1.0 and not reduced:
		# Pop: grow past full size and settle back ('퐁').
		s = lerpf(0.55, 1.0, pop) + sin(pop * PI) * 0.18
	visual_scale = Vector2.ONE * s
	if absf(s - _drawn_scale) > 0.004 or absf(halo - _drawn_halo) > 0.01 or absf(angle_difference(rotation, _drawn_rotation)) > 0.02:
		queue_redraw()

func _on_contact(other: Node) -> void:
	if held or merge_locked or destroy_pending: return
	if other is PlushieBody and is_instance_valid(manager) and other.manager == manager:
		manager.request_merge(self, other)

func top_y() -> float:
	return global_position.y - radius

func world_bounds() -> Rect2:
	return Rect2(global_position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)

func release() -> void:
	has_surface_contact = false
	held = false
	freeze = false
	sleeping = false
	collision_layer = 1
	collision_mask = 1
	age = 0.0
	linear_velocity = Vector2(0, 60)
	var spin := 0.35 if not is_instance_valid(manager) else float(manager.tweaks.value("player.release.spin"))
	angular_velocity = 0.0 if not is_instance_valid(manager) else manager.session.rng.randf_range(-spin, spin)
	add_to_group("plushies")

func _draw() -> void:
	_drawn_scale = visual_scale.x
	_drawn_halo = halo
	_drawn_rotation = rotation
	if halo > 0:
		draw_arc(Vector2.ZERO, radius + (0.6 - halo) * 40.0, 0, TAU, 48, Color(1.0, 0.95, 0.55, halo), 4, true)
	# The node's own rotation spins the pattern; lighting is drawn upright.
	BallArt.draw_ball(self, tier, Vector2.ZERO, radius * visual_scale.x, 0.0, 1.0, radius > 20.0, -rotation)
