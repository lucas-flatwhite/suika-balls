extends SceneTree
## Integration contract: local-only routes, results, profiles and resource closure.
const Standings := preload("res://scripts/score/leaderboard.gd")
var game: Node
var assertions := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
    assertions += 1
    if not value:
        failures.append(message)
        push_error(message)

func frames(count := 6) -> void:
    for unused in range(count): await process_frame

func node_has_transport(node: Node) -> bool:
    if node is HTTPRequest: return true
    for child in node.get_children():
        if node_has_transport(child): return true
    return false

func visible_text(node: Node) -> String:
    var result := ""
    if node is Label: result += node.text + "\n"
    if node is Button: result += node.text + "\n"
    for child in node.get_children(): result += visible_text(child)
    return result

func run() -> void:
    root.size = Vector2i(1440,900)
    for path in ["config/multiplayer.json", "scripts/multiplayer/client.gd", "scripts/multiplayer/discovery.gd", "scripts/multiplayer/server.gd", "scenes/multiplayer_server.tscn", "scripts/score/global_service.gd", "scripts/ranked/ranked_v2_api.gd"]:
        check(not FileAccess.file_exists("res://"+path),"Remote-only resource is absent: "+path)
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await frames()
    game.audio.set_muted(true)
    game.settings.path = "user://puzzle-local-template-settings.json"
    game.leaderboard.path = "user://puzzle-local-template-standings.json"
    game.settings.values.muted = true
    game.tweaks.reset_all()
    game.tweaks.enabled = false
    game.leaderboard.rows.clear()
    game.setting("name","Local Pilot")
    for language in ["en","zh_CN"]:
        game.locale.locale = language
        for profile in [[Vector2i(1440,900),false,true], [Vector2i(800,600),false,true], [Vector2i(600,900),false,false], [Vector2i(390,844),true,false], [Vector2i(844,390),true,false]]:
            root.size = profile[0]
            game.device.force_mobile = 1 if profile[1] else 0
            game._viewport_changed()
            await frames()
            check(game._hud.controls.has("ui.multiplayer") == profile[2],"Title entry matches shared-keyboard device eligibility: "+language+str(profile[0]))
            game.open_multiplayer()
            await frames()
            check(game.multiplayer_active() == profile[2],"Direct entry uses the same device gate: "+language+str(profile[0]))
            if profile[2]:
                var screen: Control = game._multiplayer_screen
                check(screen.controls.has("mp.local_splitscreen") and not screen.controls.has("mp.quick_match") and not screen.controls.has("mp.custom_match"),"Chooser offers only same-device play")
                check(screen.controls.username.text == "Local Pilot", "Saved username appears in local setup")
                check(not node_has_transport(game), "Opening local setup creates no HTTP transport")
                screen._leave()
                await frames()
    root.size = Vector2i(1440,900)
    game.device.force_mobile = 0
    game.locale.locale = "en"
    game._viewport_changed()
    check(game.start_stage(0),"Standard solo run starts after local setup")
    game.session.score.total = 4320
    game.session.elapsed = 12.5
    game.session.finish("defeat","timeout")
    game._finish_run()
    await frames()
    check(game.leaderboard.rows.size() == 1 and game.leaderboard.rows[0].name == "Local Pilot" and game.leaderboard.rows[0].score == 4320,"Standard result saves the profile name and score locally")
    game._finish_run()
    check(game.leaderboard.rows.size() == 1,"Repeated finish does not duplicate the local result")
    var restored := Standings.new()
    restored.path = game.leaderboard.path
    restored.load_data()
    check(restored.rows.size() == 1 and restored.rows[0].run_id == game.session.run_id,"Local standings survive a file reload")
    var result_text := visible_text(game._hud)
    check(not result_text.contains("Share") and not result_text.contains("Global") and result_text.contains("4320"),"Results retain factual score without remote sharing UI")
    game.open_modal("share")
    check(game.routes.modal() == "", "Retired share route cannot open")
    game.open_modal("leaderboard")
    await frames()
    check(not node_has_transport(game),"Opening local standings creates no HTTP requests")
    var leaderboard_text := visible_text(game._hud)
    check(leaderboard_text.contains("Local Pilot") and not leaderboard_text.contains("Global"),"Local standings show recorded player without global navigation")
    game.close_modal()
    game.return_title()
    game.open_multiplayer()
    await frames()
    var local_screen: Control = game._multiplayer_screen
    local_screen._start_local()
    await frames()
    check(local_screen.local_match.player_name == "Local Pilot", "Saved player name reaches the local authority")
    check(local_screen.local_match.boards.size() == 2, "Local authority creates both physics boards")
    local_screen.local_match._finish(1,"time")
    await frames()
    check(game.leaderboard.rows.size() == 1, "Local duel results do not enter solo standings")
    check(not node_has_transport(game),"Finishing a duel creates no HTTP transport")
    local_screen._leave()
    await frames()
    game.tweaks.enabled = true
    check(game.start_stage(0),"Owner practice run can start")
    game.session.score.total = 9000
    game.session.finish("defeat","timeout")
    game._finish_run()
    await frames()
    check(game.leaderboard.rows.size() == 1 and not game.session.score.result().eligible, "Owner practice results never alter saved standard standings")
    check(not game.leaderboard_available(), "Practice mode disables the standings navigation")
    game.return_title()
    game.queue_free()
    await frames(10)
    for path in ["user://puzzle-local-template-settings.json","user://puzzle-local-template-standings.json","user://puzzle-local-template-tweaks.json"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    await create_timer(0.25).timeout
    OS.delay_msec(250) # Let the native audio mixer release its final playback buffers.
    print("Local template assertions: ",assertions)
    if failures.is_empty(): print("PASS: local-only entry, saved profiles, results, practice isolation and no remote transport.")
    quit(0 if failures.is_empty() else 1)
