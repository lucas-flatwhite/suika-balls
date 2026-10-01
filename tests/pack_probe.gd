extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var owner := OS.has_feature("owner_preview")
    var checkpoint := OS.has_feature("checkpoint")
    print("PACK FEATURES owner=",owner," checkpoint=",checkpoint)
    for path in ["config/multiplayer.json","scripts/multiplayer/client.gd","scripts/multiplayer/server.gd","scripts/score/global_service.gd"]:
        if FileAccess.file_exists("res://"+path):
            push_error("Local template unexpectedly ships a remote service: "+path); quit(1); return
    if load("res://scripts/multiplayer/local_match.gd") == null:
        push_error("Local duel authority is missing"); quit(1); return
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.audio.set_muted(true)
    game.settings.path = "user://pack-test-settings.json"
    game.leaderboard.path = "user://pack-test-board.json"
    if game.tweaks.enabled != owner: push_error("Pack channel gate failed"); quit(1); return
    if game._hud.controls.has("ui.tweaks") != owner: push_error("Launcher pack gate failed"); quit(1); return
    if not game.start_stage(0): push_error("Pack stage/resources failed to load"); quit(1); return
    game.open_modal("tweaks")
    if not owner and game.routes.modal() != "": push_error("Release modal can be opened"); quit(1); return
    if not owner:
        var shortcut := InputEventKey.new()
        shortcut.keycode = KEY_F10
        shortcut.pressed = true
        game._unhandled_input(shortcut)
        if game.routes.modal() != "": push_error("Release shortcut is reachable"); quit(1); return
    else: game.close_modal()
    game.locale.locale = "zh_CN"
    game._hud.rebuild()
    if not game.t("hud.score",{"score":42}).contains("42"): push_error("Pack dictionaries missing"); quit(1); return
    game.open_modal("settings")
    await process_frame
    game.close_modal()
    var preview_tier: int = game.next_tier
    game.request_drop()
    game._advance_claw(0.2)
    if game.drop_count != 1: push_error("Pack could not release a physical toy"); quit(1); return
    game._advance_claw(0.6)
    if game.held_tier != preview_tier or game.held_toy.tier != preview_tier:
        push_error("Exported claw did not load its promised preview"); quit(1); return
    var sample = game.Session.new()
    sample.start(game.Stages.STAGES[0])
    var seen := {}
    for drop in range(32):
        var tier: int = sample.next_tier()
        if tier != game.BombDefinition.TIER and (tier < 0 or tier > sample.goal_tier-2):
            push_error("Exported random drop exceeded goal limit"); quit(1); return
        if tier != game.BombDefinition.TIER: seen[tier] = true
        sample.record_drop()
    if seen.size() != 2:
        push_error("Exported initial random pool did not include both eligible tiers"); quit(1); return
    var held = game.held_toy
    var run_id: String = game.session.run_id
    var a = game._spawn(2,Vector2(610,650))
    var b = game._spawn(2,Vector2(760,650))
    var remaining: float = game.session.remaining_time()
    game._merge(a,b,game._run_generation)
    if game.routes.route != "gameplay" or game.session.goal_tier != 4 or game.session.run_id != run_id or game.held_toy != held:
        push_error("Exported goal failed to preserve active play"); quit(1); return
    if game.session.remaining_time() != remaining+60.0:
        push_error("Exported goal failed to add one minute"); quit(1); return
    if not owner and game._hud.theme.default_font_size != 68:
        push_error("Exported desktop UI font was not doubled to 68 pixels"); quit(1); return
    game.queue_free()
    for frame in range(8): await process_frame
    await create_timer(0.25).timeout
    print("PASS: isolated pack boots resources, Chinese UI, controls, doubled fonts, stable randomized previews, continuous goals with one-minute extensions and build-channel gate.")
    quit()
