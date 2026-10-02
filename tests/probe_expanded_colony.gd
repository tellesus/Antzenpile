extends SceneTree
## First run evaluate_expanded_colony.gd; captures restore its ordinary, unmodified states.
const Root = preload("res://src/core/game_root.gd")
var failed: bool = false
func _initialize(): _run.call_deferred()
func _run():
	var root := Root.new()
	get_root().add_child(root)
	root.set_process(false)
	for scenario: String in ["backyard_slice", "garden_edge"]:
		for tag: String in ["climate", "refuse", "guest", "loss", "final"]:
			var path: String = "res://.godot/card075_%s_482817_%s.json" % [scenario, tag]
			if not FileAccess.file_exists(path): printerr("Missing ordinary capture: ", path); failed = true; continue
			if not root.simulation.restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path))): failed = true; continue
			root.simulation.toggle_pause()
			root._refresh_loaded_views()
			var snapshot: Dictionary = root.simulation.run.to_dict()
			for size: Vector2i in [Vector2i(1280, 720), Vector2i(900, 600)]:
				DisplayServer.window_set_size(size)
				root.set_mode("inward")
				root._inward_view.selected_id = "midden" if tag == "refuse" else "guest" if tag == "guest" else "nursery"
				await _capture("%s_%s_inward_%d" % [scenario, tag, size.x])
				if tag == "final":
					root._inward_view.activate_at(InwardView.positions(root._inward_view.get_viewport_rect().size).adaptation)
					root._inward_view.web_selection = "persistent"
					await _capture("%s_web_%d" % [scenario, size.x])
				root.set_mode("outward")
				var outward: OutwardView = root._outward_view
				outward._process(0)
				var signals: Array[Dictionary] = root.sensory_snapshot("home")
				var chosen: Dictionary = {}
				for signal_data: Dictionary in signals:
					if tag == "loss" and signal_data.risk == "reported_loss" or tag == "final" and signal_data.category == "protein": chosen = signal_data; break
				if not chosen.is_empty():
					outward.facing = chosen.bearing
					outward.selected_id = chosen.id
				await _capture("%s_%s_outward_%d" % [scenario, tag, size.x])
				if tag == "final":
					outward._run_command("sources")
					outward._run_command("source_filter_protein")
					await _capture("%s_protein_memories_%d" % [scenario, size.x])
					outward._run_command("sources")
			if snapshot != root.simulation.run.to_dict(): failed = true
	print("[EXPANDED-PROBE] ordinary saved states, both settings/views/sizes, no snapshot mutation; failed=", failed)
	root.free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
func _capture(label: String):
	for frame: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	if get_root().get_texture().get_image().save_png("res://.godot/card075_%s.png" % label) != OK: failed = true
