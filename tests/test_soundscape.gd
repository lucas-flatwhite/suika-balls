extends SceneTree

var failures: Array[String] = []
var cues: Array[StringName] = []
var game: Node
var audio: GameAudio
const SAVE := "user://mushies_save.cfg"

func _initialize() -> void:
    call_deferred("run")

func check(value: bool,message: String) -> void:
    if not value:
        failures.append(message)
        push_error(message)

func step(delta: float = 0.25) -> void:
    audio._process(delta)

func run() -> void:
    var had_save := FileAccess.file_exists(SAVE)
    var saved := FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()
    game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    game.settings.path = "user://audio-test-settings.json"
    game.leaderboard.path = "user://audio-test-leaderboard.json"
    game.tweaks.reset_all()
    game.start_stage(0)
    game.set_process(false)
    game.set_physics_process(false)
    audio = game.audio
    audio.set_process(false)
    audio.set_muted(false)
    audio.cue_played.connect(func(key: StringName) -> void: cues.append(key))
    var music_id := audio._music_player.get_instance_id()
    var stream_id := audio._music_player.stream.get_instance_id()
    var starts := audio.music_start_count
    check(audio.BANK.STREAMS.size()==19,"Exactly 19 SFX must be available")
    check(audio._sfx_players.size()==19,"Every sound must have a bounded runtime player")
    for key in audio.BANK.STREAMS:
        var player := audio.get_cue_player(key)
        check(player.stream is AudioStreamOggVorbis and player.stream.get_length()>0.1,"Every SFX must load and decode")
        check(player.bus in [&"SFX", &"UI"] and player.max_polyphony<=3,"Every effect must be routed with bounded polyphony")
    check((audio._music_player.stream as AudioStreamOggVorbis).loop,"BGM must loop")
    check((audio._carriage.stream as AudioStreamOggVorbis).loop,"Carriage must loop")
    check(AudioServer.get_bus_effect_count(0)>0,"Master bus must have a safety limiter")

    audio.set_carriage_motion(400)
    step(0.02)
    check(audio._carriage.playing and cues.has(&"carriage_loop"),"Actual movement must start one motor loop")
    var motors := cues.count(&"carriage_loop")
    audio.set_carriage_motion(450)
    step(0.02)
    check(cues.count(&"carriage_loop")==motors,"Movement must reuse its loop, not restart per frame")
    audio.set_carriage_motion(0)
    step(0.3)
    check(not audio._carriage.playing,"Stationary carriage must become silent")

    game.request_drop()
    check(cues.count(&"claw_open")==1,"Accepted drop must play claw opening")
    game.request_drop()
    check(cues.count(&"claw_open")==1,"Repeated release input must not replay the cue")
    game._advance_claw(0.19)
    check(cues.count(&"release_whoosh")==1,"Release cue must match physical release")
    game._advance_claw(0.56)
    check(cues.count(&"claw_close")==1,"Reload completion must play closing")
    game.restart_game()
    check(cues.has(&"restart"),"Restart must use its own cue")
    step()

    audio.play_impact(0.5,0,false)
    check(cues.back()==&"impact_soft_a","First light contact must choose variation A")
    var count := cues.size()
    audio.play_impact(0.5,0,false)
    check(cues.size()==count,"Rapid contact noise must be gated")
    step()
    audio.play_impact(0.5,0,false)
    check(cues.back()==&"impact_soft_b","Second light contact must alternate to B")
    step()
    audio.play_impact(0.9,8,false)
    check(cues.back()==&"impact_heavy","Large/high-energy impact must choose heavy fabric")
    step()
    audio.play_impact(0.5,0,true)
    check(cues.back()==&"wall_tap","Side-wall contacts must use wall taps")
    step()
    count=cues.size()
    audio.play_impact(0.01,0,false)
    check(cues.size()==count,"Settling must remain silent")

    audio.play_merge(1,true)
    check(cues.has(&"merge_small") and cues.back()==&"discovery","First small evolution must include discovery")
    var discoveries := cues.count(&"discovery")
    step()
    audio.play_merge(2,true)
    check(cues.back()==&"chain_bonus" and audio.chain_count==2,"Rapid first-time evolution must also add the chain reward")
    check(cues.count(&"discovery")==discoveries+1,"Chain eligibility must not suppress first discovery")
    discoveries = cues.count(&"discovery")
    step(0.5)
    audio.play_merge(3,false)
    check(cues.back()==&"chain_bonus" and audio.chain_count==3,"Rapid known evolution must retain its chain reward")
    check(cues.count(&"discovery")==discoveries,"Known tiers must not repeat discovery")
    step(1.3)
    audio.play_merge(6,false)
    check(cues.back()==&"merge_large" and audio.chain_count==1,"Large evolution must choose large sound and reset expired chain")
    step()
    count=cues.size()
    audio.play_merge(10,true)
    check(cues.size()==count+1 and cues.back()==&"dragon_arrival","Final tier must use only its priority celebration")
    count=cues.size()
    audio.play_impact(0.9,8,false)
    check(cues.size()==count,"Priority celebration must suppress clutter")
    step(2.0)
    audio.play_danger()
    count=cues.count(&"danger")
    audio.play_danger()
    check(cues.count(&"danger")==count,"Repeated warning calls must be gated")
    audio.play_game_over()
    check(cues.back()==&"game_over","Game over must use its resolution cue")
    game.restart_game()
    step()

    audio.play_bomb_pop()
    check(cues.back()==&"bomb_pop","Bomb detonation plays its dedicated fabric pop")
    step()

    game.toggle_pause()
    check(cues.back()==&"ui_open" and audio.music_mood==audio.MusicMood.DUCKED,"Pause opening must use UI-open and duck music")
    check(audio._music_player.playing and not audio._carriage.playing,"Pause must retain music but stop motor")
    step()
    game.toggle_pause()
    check(cues.back()==&"ui_click","Closing pause must use UI confirmation")
    step()
    game.return_title()
    game.toggle_help()
    check(cues.back()==&"ui_open","Title Help shortcut must use UI-open")
    step()
    game.toggle_help()
    audio.set_muted(true)
    count=cues.size()
    audio.play_merge(1,true)
    audio.play_impact(0.8,0,false)
    audio.play_ui_click()
    check(cues.size()==count,"Muted actions must not emit cues")
    check(audio._music_player.playing,"Mute must leave existing music timeline intact")
    audio.set_muted(false)
    step()
    game.restart_game()
    await create_timer(0.2).timeout
    check(audio._music_player.playing,"Background track must keep playing")
    check(audio.music_start_count==starts,"Pause, help, mute, game over and restart must not restart BGM")
    check(audio._music_player.get_instance_id()==music_id and audio._music_player.stream.get_instance_id()==stream_id,"Exactly one unchanged BGM player and stream must serve all states")
    for key in audio.BANK.STREAMS:
        check(cues.has(key),"Unexercised sound cue: "+String(key))
    print("Exercised ",audio.BANK.STREAMS.size()," SFX; continuous BGM starts: ",audio.music_start_count)
    game.queue_free()
    for frame in range(6): await process_frame
    await create_timer(0.2).timeout
    if had_save:
        var file := FileAccess.open(SAVE,FileAccess.WRITE)
        file.store_buffer(saved)
        file.close()
    else:
        DirAccess.remove_absolute(SAVE)
    if failures.is_empty():
        print("PASS: complete soundscape routing, motion, variation, priorities, controls and continuous music.")
        quit(0)
    else:
        print("FAIL: ",failures)
        quit(1)
