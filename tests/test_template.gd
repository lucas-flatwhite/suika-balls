extends SceneTree
const Stages := preload("res://data/stages/registry.gd")
const Session := preload("res://scripts/core/session.gd")
const Score := preload("res://scripts/score/score_service.gd")
const Board := preload("res://scripts/score/leaderboard.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Tweaks := preload("res://scripts/tuning/tweak_service.gd")
const Locale := preload("res://scripts/core/localization.gd")
var failures: Array[String] = []
var assertions := 0
var game: Node

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
    assertions += 1
    if not value: failures.append(message); push_error(message)
func write_json(path: String, raw: Variant) -> void:
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(JSON.stringify(raw))

func run() -> void:
    root.size = Vector2i(1440,900)
    check_random_drops()
    for stage in Stages.STAGES:
        check(Stages.validate(stage),"Authored stages validate")
        var session := Session.new()
        session.start(stage)
        var run_id := session.run_id
        session.elapsed = 12.0
        session.drops = 7
        var remaining := session.remaining_time()
        var points := session.merge(stage.target)
        check(session.outcome == "" and session.can_drop(),"Reaching a goal leaves the run playable")
        check(session.goal_tier == stage.target+1 and session.goals_reached == 1,"Goal advances to the next tier")
        check(session.elapsed == 12.0 and session.drops == 7 and session.run_id == run_id,"Goal preserves run counters and identity")
        check(session.remaining_time() == remaining+60.0,"Each goal adds exactly one minute to the remaining time")
        check(session.score.total == points+1000 and not session.score.finalized,"Goal rewards accumulate without finalizing score")
        remaining = session.remaining_time()
        session.merge(stage.target)
        check(session.remaining_time() == remaining and session.goals_reached == 1,"Merges below the current goal do not grant extra time")
        for drop in range(128): session.record_drop()
        check(session.can_drop(),"Random supply remains available after the original finite budget")
        for tier in range(session.goal_tier,11):
            remaining = session.remaining_time()
            session.merge(tier)
            check(session.remaining_time() == remaining+60.0,"Time bonuses accumulate through every subsequent tier")
        check(session.goal_tier == 10 and session.goal_quantity == 2,"Final tier advances to collecting another dragon")
        remaining = session.remaining_time()
        session.merge(10)
        check(session.goal_quantity == 3 and session.outcome == "","Repeated dragons never overflow the tier registry or end the run")
        check(session.remaining_time() == remaining+60.0,"Collecting each additional dragon also grants one minute")
        session.finish("defeat","timeout")
        remaining = session.remaining_time()
        var total := session.score.total
        var snapshot := session.score.finish({"outcome":session.outcome})
        snapshot.score = -999
        session.merge(10)
        check(session.remaining_time() == remaining,"A merge after game over cannot grant time or revive the run")
        check(session.score.result().score == total,"Result remains immutable and finalizes once at run end")
        session.finish("victory","target")
        check(session.outcome == "defeat","Terminal result cannot be overwritten")
        session.start(stage)
        check(session.goals_reached == 0 and session.goal_tier == stage.target,"Explicit restart resets progression")
        check(session.remaining_time() == float(stage.time_limit),"Explicit restart removes all earned time")
        session.tick(float(stage.time_limit)-0.25)
        session.merge(stage.target)
        session.tick(0.25)
        check(session.outcome == "" and session.remaining_time() == 60.0,"A goal just before the original deadline extends actual play")
        session.tick(59.75)
        check(session.outcome == "" and session.remaining_time() == 0.25,"The run remains playable until the extended deadline")
        session.tick(0.25)
        check(session.outcome == "defeat" and session.reason == "timeout" and session.remaining_time() == 0.0,"The extended deadline ends the run exactly once")
        check(session.elapsed == float(stage.time_limit)+60.0,"Reported duration includes the earned minute without resetting elapsed time")
        session.start(stage)
        session.tick(180)
        check(session.outcome == "defeat" and session.reason == "timeout","Authored timer still ends the run")
    var broken: Dictionary = Stages.STAGES[0].duplicate(true)
    broken.drop_mode = "authored"
    broken.drops = [0]
    broken.repeat_drops = false
    check(not Stages.validate(broken),"Insufficient mass fails validation")
    broken = Stages.STAGES[0].duplicate(true); broken.target = 11
    check(not Stages.validate(broken),"Invalid target fails validation")
    broken = Stages.STAGES[0].duplicate(true); broken.initial = [{"tier":3,"x":NAN,"y":600}]
    check(not Stages.validate(broken),"Nonfinite layout fails validation")
    var localization := Locale.new()
    var en: Dictionary = localization.dictionaries.en
    var zh: Dictionary = localization.dictionaries.zh_CN
    check(en.size() == zh.size(),"Locale key counts match")
    for key in en:
        check(zh.has(key),"Chinese key: "+key)
        var regex := RegEx.new()
        regex.compile("\\{([a-z_]+)\\}")
        var names_en := []
        var names_zh := []
        for hit in regex.search_all(en[key]): names_en.append(hit.get_string(1))
        for hit in regex.search_all(zh[key]): names_zh.append(hit.get_string(1))
        names_en.sort(); names_zh.sort()
        check(names_en == names_zh,"Matching placeholders: "+key)
        for character in String(zh[key]):
            # Layout control characters do not require a drawable font glyph.
            if character in ["\n","\r","\t"]: continue
            check(localization.font.has_char(character.unicode_at(0)),"Bundled glyph: "+character)
    localization.locale = "zh_CN"
    check(localization.t("hud.score",{"score":123}).contains("123"),"Placeholder substitution works")
    var settings := Settings.new()
    settings.path = "user://template-test-settings.json"
    write_json(settings.path,{"locale":"xx","music":"bad","muted":{},"name":"abcdefghijklmnopqrstuv"})
    settings.load_data()
    check(settings.values.locale == "en" and settings.values.music == 0.8,"Malformed settings preserve baseline")
    check(settings.values.name.length() == 20,"Names are bounded")
    # First-launch language follows the OS/browser locale; a saved choice always wins.
    for pair in [["zh_CN","zh_CN"],["zh-Hans-CN","zh_CN"],["zh_TW","zh_CN"],["ZH","zh_CN"],["en_US","en"],["ja_JP","en"],["","en"]]:
        check(Settings.detect_locale(pair[0]) == pair[1],"Locale detection maps "+pair[0]+" to "+pair[1])
    var fresh := Settings.new()
    fresh.path = "user://template-test-locale-fresh.json"
    if FileAccess.file_exists(fresh.path): DirAccess.remove_absolute(ProjectSettings.globalize_path(fresh.path))
    fresh.load_data()
    fresh.apply_detected_locale("zh_CN")
    check(not fresh.locale_saved and fresh.values.locale == "zh_CN","A first launch without a saved language follows a Chinese system locale")
    fresh.apply_detected_locale("en_GB")
    check(fresh.values.locale == "en","A first launch without a saved language follows a non-Chinese system locale")
    check(fresh.set_value("locale","zh_CN") and fresh.locale_saved,"Choosing a language persists it")
    var reloaded := Settings.new()
    reloaded.path = fresh.path
    reloaded.load_data()
    reloaded.apply_detected_locale("en_US")
    check(reloaded.locale_saved and reloaded.values.locale == "zh_CN","A saved language wins over the system locale")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(fresh.path))
    var board := Board.new()
    board.path = "user://template-test-board.json"
    write_json(board.path,{"version":1,"rows":[{},null,{"score":"oops"}]})
    board.load_data()
    check(board.rows.is_empty(),"Malformed leaderboard rows ignored")
    for index in range(12):
        var result := {"run_id":"run-%02d" % index,"name":"Player","score":index*100,"stage":"first_hugs",
            "outcome":"victory","timestamp":index,"duration":float(30-index),"config":"baseline-test","eligible":true}
        var tweaked := result.duplicate(true)
        tweaked.eligible = false
        tweaked.run_id += "-tweaked"
        check(not board.record(tweaked),"Tweak-affected runs cannot enter the leaderboard")
        check(board.record(result),"Leaderboard writes valid rows")
        if index == 11: check(not board.record(result),"Duplicate run cannot be submitted twice")
    var restored := Board.new(); restored.path = board.path; restored.load_data()
    check(restored.rows.size() == 10 and restored.rows[0].score == 1100,"Local top ten persists sorted")
    var ranked_result: Dictionary = restored.rows[0].duplicate(true)
    ranked_result.run_id = "faster"; ranked_result.duration = 0.5
    restored.record(ranked_result)
    check(restored.rows[0].run_id == "faster","Tie breaks on duration")
    var tuning := Tweaks.new(true)
    check(tuning.descriptors.size() >= 24,"Substantial catalog")
    var categories := {}
    for descriptor in tuning.descriptors:
        categories[descriptor.category] = true
        for field in ["id","category","type","default","min","max","step","unit","apply_mode","integrity","label_key","description_key"]:
            check(descriptor.has(field),"Complete descriptor metadata")
        check(en.has(descriptor.label_key) and zh.has(descriptor.description_key),"Catalog is fully localized")
        check(tuning.valid(descriptor.id,descriptor.default),"Baseline validates: "+descriptor.id)
    check(categories.size() == 6,"All six categories exist")
    check(not tuning.request("enemies.toy.bounce",NAN),"Reject nonfinite value")
    check(not tuning.request("enemies.toy.bounce",0.99),"Reject out-of-range value")
    check(not tuning.request("player.aim.speed",421),"Reject off-step value")
    check(not tuning.request("ui.reduced_motion",1),"Reject boolean coercion")
    tuning.begin_run()
    tuning.request("ui.hud.opacity",0.8)
    check(not tuning.tainted and tuning.value("ui.hud.opacity") == 0.8,"Cosmetics apply live without taint")
    tuning.request("enemies.toy.bounce",0.5)
    check(not tuning.tainted and tuning.value("enemies.toy.bounce") == 0.46,"Spawn request is deferred")
    tuning.apply("NEXT_SPAWN")
    check(tuning.tainted and tuning.value("enemies.toy.bounce") == 0.5,"Applied gameplay change taints run")
    tuning.reset_all(); tuning.apply("NEXT_SPAWN")
    check(tuning.tainted,"Reset does not erase current run taint")
    tuning.begin_run(); check(not tuning.tainted,"Fresh baseline run clears previous taint")
    tuning.request("player.claw.open_seconds",0.2)
    check(tuning.value("player.claw.open_seconds") == 0.18,"Action value is deferred")
    tuning.apply("NEXT_ACTION"); check(tuning.value("player.claw.open_seconds") == 0.2,"Action boundary applies")
    tuning.request("gameplay.score.multiplier",2.0)
    check(tuning.value("gameplay.score.multiplier") == 1.0,"Run value is deferred")
    check(not tuning.has_method("load_data") and not tuning.has_method("flush_now"),"Preview tuning has no persisted draft")
    var release_tuning := Tweaks.new(false); release_tuning.begin_run()
    check(release_tuning.value("gameplay.score.multiplier") == 1.0 and not release_tuning.request("gameplay.score.multiplier",2.0),"Release cannot apply owner draft")
    var before_invalid_patch := tuning.requested.duplicate(true)
    check(not tuning.apply_preview_patch({"ui.hud.opacity":0.8,"unknown":2}),"Invalid batch is rejected")
    check(tuning.requested == before_invalid_patch,"Invalid batch cannot partially apply")
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.settings.path = "user://template-test-game-settings.json"
    game.leaderboard.path = "user://template-test-game-board.json"
    game.tweaks.reset_all()
    check(game.routes.route == "title" and game.is_frozen(),"Title owns initial route")
    game.start_stage(0)
    check(game._hud.theme.default_font_size == 68,"Desktop menu typography is preserved")
    check(game._hud.metrics.score.get_theme_font_size("font_size") == 36,"Desktop gameplay uses reduced readout typography")
    var survivor: PlushieBody = game._spawn(0,Vector2(500,700))
    var first: PlushieBody = game._spawn(2,Vector2(650,650))
    var second: PlushieBody = game._spawn(2,Vector2(750,650))
    var held: PlushieBody = game.held_toy
    var preview_tier: int = game.next_tier
    var id: String = game.session.run_id
    var generation: int = game._run_generation
    game.session.elapsed = 10.0
    game.session.drops = 5
    var records: int = game.leaderboard.rows.size()
    game._merge(first,second,generation)
    check(game.routes.route == "gameplay" and game.routes.stack.is_empty(),"Goal merge never opens results or any announcement modal")
    check(game._run_generation == generation and game.session.run_id == id,"Goal merge does not start a new run")
    check(is_instance_valid(survivor) and not survivor.is_queued_for_deletion() and game.held_toy == held,"Existing pile and held plushie survive goal advancement")
    check(game.next_tier == preview_tier and game.session.next_tier(1) == preview_tier,"Goal advancement preserves the promised next drop")
    check(game.session.elapsed == 10.0 and game.session.drops == 5,"Timer and drop counter survive goal advancement")
    check(game.session.remaining_time() == 230.0,"Physical goal merge extends the active countdown by one minute")
    check(game.session.goal_tier == 4 and not game._hud.metrics.has("status"),"Goal changes silently without a merge announcement")
    check(not game._recorded and game.leaderboard.rows.size() == records and game.tweaks.running,"Goal does not submit a result or end the active tuning session")
    game._hud._process(0)
    check(game._hud.metrics.time.text.contains("3:50"),"HUD countdown immediately displays earned time")
    check(game._hud.metrics.goal.text.contains(game.toy_name(4)),"Goal label updates in place")
    check(game._hud.metrics.goal_texture.texture == game.Plush.TEXTURES[4],"Goal image updates in place")
    game.request_drop()
    game._advance_claw(0.2)
    game._advance_claw(0.6)
    game._hud._process(0)
    check(game.held_tier == preview_tier and game.held_toy.tier == preview_tier,"Claw loads the exact randomized toy previously shown in Next")
    check(game._hud.metrics.next.text.contains(game.toy_name(game.session.next_tier(1))),"HUD displays the newly queued random preview")
    game.start_stage(0)
    check(game.scale == Vector2.ONE,"Physics board never scales with viewport")
    var mass: float = game.held_toy.mass
    var original_outline: PackedVector2Array = game.held_toy.outline.duplicate()
    root.size = Vector2i(390,844)
    game._viewport_changed()
    game.start_stage(0)
    game._hud.rebuild()
    await process_frame
    check(game._hud.controls["ui.pause"].get_global_rect().end.x <= 390,"Mobile pause/menu button remains inside the viewport")
    check(game.held_toy.mass == mass and game.held_toy.outline == original_outline,"Portrait projection preserves physical geometry")
    game.open_modal("pause")
    await process_frame
    var pause_button: Button = game._hud.controls["ui.settings"]
    pause_button.grab_focus()
    game.open_modal("settings")
    game.open_modal("collection")
    check(game.routes.stack.size() == 3 and game.is_frozen(),"Nested modals preserve frozen state")
    game.close_modal(); await process_frame
    check(game.routes.modal() == "settings" and game.is_frozen(),"Nested close restores settings")
    game.close_modal(); await process_frame
    check(game.routes.modal() == "pause" and game.is_frozen(),"Settings close restores pause")
    check(pause_button.has_focus(),"Closing modal restores exact prior control focus")
    game.close_modal(); await process_frame
    check(not game.is_frozen(),"Pause close restores active simulation")
    game.open_modal("collection")
    await process_frame
    game.close_modal()
    for frame in range(2): await process_frame
    check(game._hud.collection_views.is_empty(),"Closed collection view releases its update references")
    game.open_modal("tweaks")
    check(game.routes.modal() != "tweaks" and not game.is_frozen(),"Removed native tuning route cannot pause gameplay")
    var synthetic: Dictionary = Stages.STAGES[0].duplicate(true)
    synthetic.id = "synthetic_third"
    check(game.start_stage(2,synthetic),"Additional stage definition needs no core routing changes")
    # Cross-frame retry must discard queued merges from the previous run.
    var a: PlushieBody = game._spawn(0,Vector2(620,650))
    var b: PlushieBody = game._spawn(0,Vector2(730,650))
    game.request_merge(a,b)
    game.restart_game()
    await process_frame
    check(game.score == 0 and game.merge_count == 0,"Retry discards previous queued merge")
    for index in range(200): game.feedback.burst(Vector2(700,600))
    check(game.feedback.particles.size() <= game.feedback.MAX_PARTICLES,"Particle population is bounded")
    game.feedback.clear(); game.feedback.reduced_motion = true; game.feedback.burst(Vector2.ZERO)
    check(game.feedback.particles.is_empty(),"Reduced motion suppresses emissions")
    game.return_title()
    check(get_nodes_in_group("plushies").is_empty(),"Return to title clears actors")
    game.queue_free()
    for frame in range(8): await process_frame
    print("Template assertions: ",assertions)
    if failures.is_empty(): print("PASS: stages, scoring, persistence, localization, tuning, route/focus and reset invariants.")
    OS.delay_msec(250)
    quit(0 if failures.is_empty() else 1)

func check_random_drops() -> void:
    for goal in range(2,11):
        var definition: Dictionary = Stages.STAGES[0].duplicate(true)
        definition.target = goal
        var session := Session.new()
        var replay := Session.new()
        check(session.start(definition) and replay.start(definition),"Random stages validate from minimum goal to final tier")
        var opening := [session.next_tier(),session.next_tier(1)]
        var seen := {}
        for drop in range(128):
            var tier := session.next_tier()
            var preview := session.next_tier(1)
            if tier != Session.Bomb.TIER: seen[tier] = true
            check(tier == Session.Bomb.TIER or (tier >= 0 and tier <= goal-2),"Ordinary drops stay two tiers below the goal; bombs are a separate 1% item")
            check(session.next_tier(1) == preview and session.next_tier() == tier,"Preview reads do not reroll the queue")
            replay.rng.randf_range(-1.0,1.0)
            check(replay.next_tier() == tier,"Seeded drops reproduce independently of release physics randomness")
            session.record_drop()
            replay.record_drop()
            check(session.next_tier() == preview,"Release consumes exactly one queued toy and preserves the preview")
        check(seen.size() == goal-1,"Every eligible tier appears in the seeded sample")
        var held := session.next_tier()
        var preview := session.next_tier(1)
        session.merge(goal)
        check(session.next_tier() == held and session.next_tier(1) == preview,"Goal expansion leaves held and preview toys unchanged")
        var expanded := {}
        for drop in range(128):
            session.record_drop()
            expanded[session.next_tier(1)] = true
        check(expanded.has(mini(goal-1,8)),"Future random draws include the newly unlocked tier, capped below the final goal")
        session.start(definition)
        check([session.next_tier(),session.next_tier(1)] == opening,"Restart resets the queue and drop random stream")
        session.finish("defeat","timeout")
        session.record_drop()
        check(session.drops == 0 and [session.next_tier(),session.next_tier(1)] == opening,"Game over cannot consume or reroll drops")
    var first := Session.new()
    var second := Session.new()
    var different_seed: Dictionary = Stages.STAGES[1].duplicate(true)
    different_seed.seed += 1
    first.start(Stages.STAGES[1]); second.start(different_seed)
    var differs := false
    for drop in range(32):
        differs = differs or first.next_tier() != second.next_tier()
        first.record_drop(); second.record_drop()
    check(differs,"Distinct authored seeds produce different drop sequences")
    var finite: Dictionary = Stages.STAGES[0].duplicate(true)
    finite.erase("drop_mode")
    finite.target = 2
    finite.drops = [0,0,1]
    check(first.start(finite),"Existing authored definitions remain supported without a mode field")
    for tier in finite.drops:
        check(first.can_drop() and first.next_tier() == tier,"Finite authored drops retain exact order")
        first.record_drop()
    check(not first.can_drop(),"Finite authored supplies still exhaust")
    finite.repeat_drops = true
    first.start(finite)
    for drop in range(10):
        check(first.next_tier() == finite.drops[drop%3],"Explicit repeating authored patterns retain their order")
        first.record_drop()
    var invalid: Dictionary = Stages.STAGES[0].duplicate(true)
    invalid.drop_mode = "unknown"
    check(not Stages.validate(invalid),"Unknown supply mode is rejected")
    invalid.drop_mode = "goal_random"
    invalid.target = 1
    check(not Stages.validate(invalid),"Random goals must leave room for the two-tier gap")
