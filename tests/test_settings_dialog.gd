extends SceneTree
## Focused native regression for the standalone compact settings dialog.
## Optional renderer evidence: godot --path . --script tests/test_settings_dialog.gd -- --capture /absolute/output

const Dialog := preload("res://scripts/ui/settings_dialog.gd")
const Settings := preload("res://scripts/core/settings.gd")
const SAVE := "user://settings-dialog-regression.json"

var failures: Array[String] = []
var assertions := 0
var game: Node
var dialog: Control
var capture_directory := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	assertions += 1
	if value: return
	failures.append(message)
	push_error(message)

func settle(frames := 6) -> void:
	for frame in range(frames): await process_frame

func delete_save() -> void:
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

func set_locale(locale: String) -> void:
	game.locale.locale = locale
	game.settings.values.locale = locale
	TranslationServer.set_locale(locale)

func mount(size: Vector2i, mobile := false, locale := "en") -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
		await settle(2)
	root.size = size
	game.device.force_mobile = 1 if mobile else 0
	game.device.safe_insets = Vector4(0,44,0,34) if mobile else Vector4.ZERO
	set_locale(locale)
	game._viewport_changed()
	dialog = Dialog.new()
	dialog.hud = game._hud
	game._hud.add_child(dialog)
	await settle()

func card_in_bounds(mobile: bool, label: String) -> void:
	var rect: Rect2 = dialog.card.get_global_rect()
	var view: Rect2 = Rect2(Vector2.ZERO,Vector2(root.size))
	check(view.encloses(rect),label+": card remains inside the viewport")
	if mobile:
		check(rect.position.y >= game.device.safe_insets.y+12 and rect.end.y <= root.size.y-game.device.safe_insets.w-12,label+": card respects top and bottom safe insets")
	else:
		check(rect.size.x <= 920.1 and rect.size.y <= 640.1,label+": desktop card stays within the approved 920 × 640 cap")

func controls_have_touch_targets(label: String) -> void:
	var targets: Array[Control] = [dialog.close_button]
	targets.append(dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/ProfileGroup/Content/username_input"))
	targets.append(dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/ProfileGroup/Content/LanguageRow/LanguageSelect"))
	for id in ["MasterMute","MusicEnabled","SfxEnabled","ReducedMotion"]:
		targets.append(dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/"+("LeftColumn/PreferencesGroup" if id == "ReducedMotion" else "AudioGroup")+"/Content/"+id))
	for bus in ["master","music","sfx","ui"]:
		targets.append(dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/AudioGroup/Content/VolumeRow_"+bus+"/Volume_"+bus))
	for target in targets:
		check(target.custom_minimum_size.y >= 44.0,target.name+" is configured as a 44 px minimum target: "+label)

func dialog_has_expected_structure(locale: String, mobile: bool) -> void:
	check(dialog.get_node_or_null("Card") != null,"Dialog creates a centered card: "+locale)
	check(dialog.get_node_or_null("Card/CardLayout/SettingsHeaderRow/SettingsHeader") != null,"Dialog creates a clear title header: "+locale)
	check(dialog.close_button.text == game.t("settings.close"),"Header exposes localized always-visible Close: "+locale)
	check(dialog.groups.find_child("ProfileGroup",true,false) != null and dialog.groups.find_child("AudioGroup",true,false) != null and dialog.groups.find_child("PreferencesGroup",true,false) != null,"Dialog has Profile, Audio, and Preferences groups: "+locale)
	check(dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/ProfileGroup/Content/GroupTitle").text == game.t("settings.profile"),"Profile group uses localized heading: "+locale)
	check(dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/AudioGroup/Content/GroupTitle").text == game.t("settings.audio"),"Audio group uses localized heading: "+locale)
	check(dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/PreferencesGroup/Content/GroupTitle").text == game.t("settings.preferences"),"Preferences group uses localized heading: "+locale)
	var username: LineEdit = dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/ProfileGroup/Content/username_input")
	check(username.get_script() == preload("res://scripts/core/username_input.gd"),"Profile retains the shared UsernameInput: "+locale)
	var scroll: ScrollContainer = dialog.get_node("Card/CardLayout/SettingsScroll")
	check(not scroll.is_ancestor_of(dialog.close_button),"Close remains outside scrolling settings content: "+locale)
	check(not scroll.is_ancestor_of(dialog.get_node("Card/CardLayout/SettingsFooter")),"Autosave footer remains outside scrolling settings content: "+locale)
	check(dialog.find_child("AudioPreview",true,false) == null,"Dialog contains no audio-preview button: "+locale)
	check(dialog.groups.columns == (1 if mobile else 2),"Dialog uses the expected responsive group columns: "+locale)
	card_in_bounds(mobile,"Settings "+locale)
	controls_have_touch_targets(locale)

func settings_bindings_persist() -> void:
	set_locale("en")
	await mount(Vector2i(1440,900),false,"en")
	var username: LineEdit = dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/ProfileGroup/Content/username_input")
	username.text = "Mallow "
	username.text_changed.emit(username.text)
	var master: HSlider = dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/AudioGroup/Content/VolumeRow_master/Volume_master")
	master.value = 40
	var music_toggle: CheckButton = dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/AudioGroup/Content/MusicEnabled")
	music_toggle.toggled.emit(false)
	var motion_toggle: CheckButton = dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/PreferencesGroup/Content/ReducedMotion")
	motion_toggle.toggled.emit(true)
	await settle()
	check(game.settings.values.name == "Mallow","Shared UsernameInput saves its canonical name")
	check(is_equal_approx(float(game.settings.values.master),0.4),"Master slider writes its persisted normalized value")
	check(not game.settings.values.music_enabled and game.settings.values.reduced_motion,"Independent toggle and reduced-motion bindings write settings")
	var percent: Label = dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/AudioGroup/Content/VolumeRow_master/VolumeValue_master")
	check(percent.text == "40%","Master slider displays the volume value inline")
	var restored := Settings.new()
	restored.path = SAVE
	restored.load_data()
	check(restored.values.name == "Mallow" and is_equal_approx(float(restored.values.master),0.4) and not restored.values.music_enabled and restored.values.reduced_motion,"Dialog changes persist through the existing settings service")

	game.settings.path = "user://missing-settings-test-directory/preferences.json"
	check(not game.settings.set_value("master",0.5) and not game.settings.saved,"Failed settings writes are reported honestly")
	dialog._process(0)
	check(dialog.get_node("Card/CardLayout/SettingsFooter/SettingsSavedNote").text == game.t("settings.save_failed"),"Footer reports actual save failure rather than claiming success")
	game.settings.path = SAVE
	game.setting("master",0.4)

func capture(label: String) -> void:
	if capture_directory.is_empty(): return
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(),"Native renderer returns a settings capture: "+label)
	if image != null and not image.is_empty():
		check(image.save_png(capture_directory.path_join(label+".png")) == OK,"Native renderer saves settings capture: "+label)

func verify_close() -> void:
	if is_instance_valid(dialog): dialog.queue_free()
	await settle(2)
	game.open_modal("settings")
	await settle()
	dialog = Dialog.new()
	dialog.hud = game._hud
	game._hud.add_child(dialog)
	await settle()
	dialog.close_button.pressed.emit()
	await settle()
	check(game.routes.modal().is_empty(),"Header Close closes the active settings route")

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var capture_index := arguments.find("--capture")
	if capture_index >= 0 and arguments.size() > capture_index+1:
		capture_directory = arguments[capture_index+1]
		DirAccess.make_dir_recursive_absolute(capture_directory)
	delete_save()
	root.size = Vector2i(1440,900)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.settings.path = SAVE
	game.settings.values = Settings.DEFAULTS.duplicate()
	game.leaderboard.path = "user://settings-dialog-regression-board.json"
	game.tweaks.reset_all()
	game.audio.set_muted(true)
	game.setting("master",0.35)
	game.setting("music",0.55)
	game.setting("sfx",0.65)
	game.setting("ui",0.75)

	await mount(Vector2i(1440,900),false,"en")
	dialog_has_expected_structure("en",false)
	check(is_equal_approx((dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/AudioGroup/Content/VolumeRow_master/Volume_master") as HSlider).value,35.0),"Saved master volume populates the English slider")
	capture("settings-en-1440x900")
	await mount(Vector2i(320,568),true,"zh_CN")
	dialog_has_expected_structure("zh_CN",true)
	check((dialog.get_node("Card/CardLayout/SettingsScroll/SettingsGroups/LeftColumn/ProfileGroup/Content/LanguageRow/LanguageSelect") as OptionButton).selected == 1,"Chinese locale selects Simplified Chinese")
	capture("settings-zh_CN-320x568")
	await settings_bindings_persist()
	await verify_close()

	if is_instance_valid(game): game.queue_free()
	await settle()
	await create_timer(1.0).timeout
	delete_save()
	for path in ["user://settings-dialog-regression-board.json","user://settings-dialog-regression-tweaks.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Settings dialog assertions: ",assertions)
	if failures.is_empty(): print("PASS: compact bilingual settings dialog structure, persistence, close behavior, responsive bounds, targets, and optional native captures.")
	else: print("FAIL: ",failures)
	quit(0 if failures.is_empty() else 1)
