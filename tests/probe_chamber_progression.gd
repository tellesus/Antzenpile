extends "res://tests/probe_sensory_art.gd"
## Detached progression fixtures; no unpaid construction in authoritative state.

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	game_root = Root.new()
	get_root().add_child(game_root)
	game_root.set_process(false)
	game_root.simulation.toggle_pause()
	var before: Dictionary = game_root.simulation.run.to_dict()
	game_root.set_mode("inward")
	var view: InwardView = game_root._inward_view
	var local: Dictionary = game_root.inward_status("home")
	view.status_provider = func() -> Dictionary: return local
	await _capture("card089_primitive")
	local.nursery_state = "developing"
	local.nursery_progress = local.nursery_build_duration*0.5
	local.food_exchange_state = "developing"
	local.food_exchange_progress = local.food_exchange_duration*0.5
	await _capture("card089_developing")
	local.nursery_state = "developed"
	local.food_exchange_state = "developed"
	local.nursery_brood_capacity = 16
	await _capture("card089_developed")
	local.nursery_expansion.state = "developing"
	local.nursery_expansion.progress_seconds = local.nursery_expansion.duration*0.5
	await _capture("card089_expanding")
	local.nursery_expansion.state = "developed"
	local.nursery_brood_capacity = 32
	local.nursery_max_care_capacity = 32
	await _capture("card089_expanded")
	view.selected_id = "nursery"
	DisplayServer.window_set_size(Vector2i(900,600))
	await _capture("card089_expanded_compact")
	view.selected_id = "adaptation"
	await _capture("card089_web_compact")
	view.selected_id = ""
	game_root._audio_settings.opened = true
	await _capture("card089_sound_compact")
	if before != game_root.simulation.run.to_dict(): failed = true
	print("[ART-PROBE] progression_snapshot_equal=%s" % (before == game_root.simulation.run.to_dict()))
	game_root.free()
	quit(1 if failed else 0)

