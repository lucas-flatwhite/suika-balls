extends SceneTree
## Focused regression: independent BGM/SFX settings persist, preserve slider values,
## and gate the shared audio buses used by solo and multiplayer presentation.

const Settings := preload("res://scripts/core/settings.gd")
const SAVE := "user://audio-settings-regression.json"
const LEGACY_SAVE := "user://audio-settings-legacy.json"

var failures: Array[String] = []
var assertions := 0
var game: Node
var cues: Array[StringName] = []
var capture_path := ""

func _initialize() -> void:
    call_deferred("run")

func check(value: bool, message: String) -> void:
    assertions += 1
    if not value:
        failures.append(message)
        push_error(message)

func settle(frames := 4) -> void:
    for frame in range(frames):
        await process_frame

func delete_save(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)

func switch_with_text(owner: Node, label: String) -> CheckButton:
    if owner is CheckButton and owner.text == label:
        return owner
    for child in owner.get_children():
        var found := switch_with_text(child, label)
        if found != null:
            return found
    return null

func bus_muted(bus: StringName) -> bool:
    var index := AudioServer.get_bus_index(bus)
    check(index >= 0, "Audio bus exists: " + String(bus))
    return index >= 0 and AudioServer.is_bus_mute(index)

func capture_settings() -> void:
    if capture_path.is_empty(): return
    await settle(8)
    RenderingServer.force_draw(false)
    var image := root.get_texture().get_image()
    check(image != null and not image.is_empty(), "Native settings panel capture is available")
    if image != null and not image.is_empty():
        check(image.save_png(capture_path) == OK, "Native settings panel capture saves successfully")

func test_legacy_defaults() -> void:
    delete_save(LEGACY_SAVE)
    var old_file := FileAccess.open(LEGACY_SAVE, FileAccess.WRITE)
    old_file.store_string(JSON.stringify({"master":0.35, "music":0.55, "sfx":0.65, "ui":0.75}))
    old_file.close()
    var legacy := Settings.new()
    legacy.path = LEGACY_SAVE
    legacy.load_data()
    check(legacy.values.music_enabled and legacy.values.sfx_enabled, "Older settings default both new audio toggles to enabled")
    check(is_equal_approx(float(legacy.values.master),0.35) and is_equal_approx(float(legacy.values.music),0.55) and is_equal_approx(float(legacy.values.sfx),0.65) and is_equal_approx(float(legacy.values.ui),0.75), "Older settings retain every stored audio slider volume")

func run() -> void:
    var arguments := OS.get_cmdline_user_args()
    var capture_index := arguments.find("--capture")
    if capture_index >= 0 and arguments.size() > capture_index+1:
        capture_path = arguments[capture_index+1]
        DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
    test_legacy_defaults()
    game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await settle()
    delete_save(SAVE)
    game.settings.path = SAVE
    game.settings.values = Settings.DEFAULTS.duplicate()
    # First launch follows the machine locale; pin English so the checks below are locale-independent.
    game.setting("locale","en")
    game.leaderboard.path = "user://audio-settings-regression-board.json"
    game.tweaks.reset_all()
    game.setting("muted",false)
    game.setting("master",0.35)
    game.setting("music",0.55)
    game.setting("sfx",0.65)
    game.setting("ui",0.75)
    game.setting("music_enabled",false)
    game.setting("sfx_enabled",false)

    var restored := Settings.new()
    restored.path = SAVE
    restored.load_data()
    check(not restored.values.music_enabled and not restored.values.sfx_enabled, "Independent audio toggle choices persist across settings reload")
    check(is_equal_approx(float(restored.values.master),0.35) and is_equal_approx(float(restored.values.music),0.55) and is_equal_approx(float(restored.values.sfx),0.65) and is_equal_approx(float(restored.values.ui),0.75), "Audio toggle changes do not reset stored slider volumes")

    game.open_modal("settings")
    await settle()
    var music_toggle := switch_with_text(game._hud, "Background music")
    var sfx_toggle := switch_with_text(game._hud, "Sound effects")
    check(music_toggle != null and not music_toggle.button_pressed, "English Settings renders the persisted Background music switch")
    check(sfx_toggle != null and not sfx_toggle.button_pressed, "English Settings renders the persisted Sound effects switch")
    game.setting("locale","zh_CN")
    await settle()
    music_toggle = switch_with_text(game._hud, "背景音乐")
    sfx_toggle = switch_with_text(game._hud, "音效")
    check(music_toggle != null and not music_toggle.button_pressed, "Chinese Settings renders the persisted Background music switch")
    check(sfx_toggle != null and not sfx_toggle.button_pressed, "Chinese Settings renders the persisted Sound effects switch")
    await capture_settings()

    var audio = game.audio
    audio.cue_played.connect(func(cue: StringName) -> void: cues.append(cue))
    game.setting("locale","en")
    game.setting("music_enabled",true)
    game.setting("sfx_enabled",true)
    game.setting("muted",false)
    audio.clear_transients()
    check(not bus_muted(&"Music") and not bus_muted(&"SFX") and not bus_muted(&"UI"), "Enabled independent audio settings leave all child buses audible")

    game.setting("sfx_enabled",false)
    check(not bus_muted(&"Music"), "Disabling SFX leaves background music independent and audible")
    check(bus_muted(&"SFX") and bus_muted(&"UI"), "Disabling SFX mutes both gameplay and interface buses")
    var before := cues.size()
    audio.play_release()
    audio.play_ui_click()
    audio.set_carriage_motion(400.0)
    audio._process(0.02)
    check(cues.size() == before and not audio._carriage.playing, "Disabled SFX suppresses gameplay, UI, and carriage-loop cues")

    game.setting("sfx_enabled",true)
    game.setting("music_enabled",false)
    check(bus_muted(&"Music"), "Disabling music mutes only the music bus")
    check(not bus_muted(&"SFX") and not bus_muted(&"UI"), "SFX and UI remain audible when only music is disabled")
    audio.clear_transients()
    before = cues.size()
    audio.play_release()
    check(cues.size() == before+1 and cues.back() == &"release_whoosh", "Shared cue service remains available for multiplayer and solo SFX when music is disabled")

    game.setting("music_enabled",true)
    check(not bus_muted(&"Music") and audio._music_player.playing, "Re-enabling music unmutes the existing continuous BGM player")
    game.setting("muted",true)
    check(bus_muted(&"Music") and bus_muted(&"SFX") and bus_muted(&"UI"), "Existing all-audio mute overrides both independent settings")
    game.setting("muted",false)
    check(not bus_muted(&"Music") and not bus_muted(&"SFX") and not bus_muted(&"UI"), "Clearing all-audio mute restores enabled independent buses")

    var master_index := AudioServer.get_bus_index(&"Master")
    var master_was_muted := AudioServer.is_bus_mute(master_index)
    AudioServer.set_bus_mute(master_index,true)
    game.setting("music_enabled",false)
    game.setting("sfx_enabled",true)
    check(AudioServer.is_bus_mute(master_index), "Independent toggles do not override an existing Master bus mute")
    AudioServer.set_bus_mute(master_index,master_was_muted)

    game.queue_free()
    await settle()
    await create_timer(0.25).timeout
    delete_save(SAVE)
    delete_save(LEGACY_SAVE)
    delete_save("user://audio-settings-regression-board.json")
    delete_save("user://audio-settings-regression-tweaks.json")
    print("Audio settings assertions: ",assertions)
    if failures.is_empty():
        print("PASS: independent BGM/SFX persistence, bilingual settings controls, bus routing, and master-mute preservation.")
    else:
        print("FAIL: ",failures)
    quit(0 if failures.is_empty() else 1)
