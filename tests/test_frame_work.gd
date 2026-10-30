extends SceneTree
## Count real canvas invalidations, including animation's final clearing frame.
const BallIcon := preload("res://scripts/ui/ball_icon.gd")
const Feedback := preload("res://scripts/vfx/feedback.gd")
var failures: Array[String] = []
var draws := {"icon": 0, "feedback": 0}

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func frames(count := 3) -> void:
	for unused in range(count):
		await process_frame
		RenderingServer.force_draw()

func _run() -> void:
	var icon := BallIcon.new()
	icon.size = Vector2(64, 64)
	icon.tier = 7
	root.add_child(icon)
	icon.draw.connect(func(): draws.icon += 1)
	var fx := Feedback.new()
	root.add_child(fx)
	fx.draw.connect(func(): draws.feedback += 1)
	await frames()
	draws.icon = 0
	draws.feedback = 0
	for unused in range(60):
		# The shipping HUD assigns next_tier every frame.
		icon.tier = 7
		icon.dim = false
		await frames(1)
	check(draws.icon == 0, "Unchanged preview has zero redraws in 60 frames (%d)" % draws.icon)
	check(not icon.is_processing(), "Idle icons do not process frames")
	check(draws.feedback == 0, "Empty feedback has zero redraws in 60 frames (%d)" % draws.feedback)
	# Each visible property must still invalidate the cached drawing.
	for property in ["tier", "dim", "spin", "size"]:
		draws.icon = 0
		match property:
			"tier": icon.tier = 8
			"dim": icon.dim = true
			"spin": icon.spin = 0.5
			"size": icon.size = Vector2(80, 80)
		await frames()
		check(draws.icon == 1, "Changing %s redraws once (%d)" % [property, draws.icon])
	icon.highlight = 0.15
	check(icon.is_processing(), "A new highlight wakes an idle icon")
	await frames(20)
	check(icon.highlight == 0.0 and not icon.is_processing(), "Highlight finishes and returns to idle")
	draws.icon = 0
	await frames()
	check(draws.icon == 0, "Completed highlight leaves no redraw loop")
	# Mixed expiry must retain every live effect, its order and its motion.
	fx.burst(Vector2(200, 300))
	fx.popup(Vector2(200, 300), "+10")
	fx.particles[0].life = 0.001
	fx.particles[1].life = 0.001
	var survivor: Dictionary = fx.particles[2]
	var position_before: Vector2 = survivor.p
	var count_before := fx.particles.size()
	var particle_array := fx.particles
	var popup_array := fx.popups
	fx.set_process(false)
	fx._process(0.02)
	check(fx.particles.size() == count_before - 2 and fx.particles[0] == survivor, "Adjacent expired particles are removed without reordering survivors")
	check(survivor.p != position_before and fx.popups[0].p.y < 300, "Live particles and popups still move")
	check(is_same(particle_array, fx.particles) and is_same(popup_array, fx.popups), "Effect arrays are updated in place")
	await frames()
	draws.feedback = 0
	fx.paused = true
	var life_before: float = survivor.life
	fx._process(0.2)
	await frames()
	check(survivor.life == life_before and draws.feedback == 0, "Paused feedback preserves its state and cached drawing")
	fx.clear()
	await frames()
	check(fx.particles.is_empty() and fx.popups.is_empty() and fx.pulse == 0 and draws.feedback == 1, "Clearing paused feedback erases its cached drawing")
	fx.paused = false
	fx.reduced_motion = true
	fx.burst(Vector2.ZERO)
	check(fx.particles.is_empty() and fx.pulse > 0, "Reduced motion retains its pulse without particles")
	fx._process(1.0)
	await frames()
	check(fx.pulse == 0, "Pulse expires normally")
	fx.reduced_motion = false
	fx.celebrate(Vector2.ZERO)
	fx.popup(Vector2.ZERO, "+100")
	fx._process(3.0)
	await frames()
	check(fx.particles.is_empty() and fx.popups.is_empty(), "Confetti and popups expire completely")
	draws.feedback = 0
	fx._process(0.1)
	await frames()
	check(draws.feedback == 0, "Expired effects return to zero redraws")
	icon.queue_free()
	fx.queue_free()
	await frames()
	# A settings change clears particles from outside Feedback._process().
	var game = load("res://scenes/main.tscn").instantiate()
	game.settings.path = "user://frame-work-settings.json"
	root.add_child(game)
	game.settings.values.reduced_motion = false
	game._apply_presentation()
	game.start_stage(0)
	await frames()
	game.feedback.set_process(false)
	game.feedback.celebrate(Vector2(300, 600))
	game.feedback.popup(Vector2(300, 600), "+100")
	game.feedback._process(1.0)
	await frames()
	check(not game.feedback.particles.is_empty() and game.feedback.popups.is_empty() and game.feedback.pulse == 0, "Reduced-motion fixture has only lingering confetti")
	draws.feedback = 0
	game.feedback.draw.connect(func(): draws.feedback += 1)
	game.setting("reduced_motion", true)
	game.feedback._process(0.02)
	await frames()
	check(game.feedback.particles.is_empty() and draws.feedback == 1, "Enabling reduced motion erases lingering cached confetti")
	game.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frame-work-settings.json"))
	print("RESULT %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
