extends SceneTree
## External verification of the unchanged packaged PCK, never shipped to players.
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
var game_root: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game_root = Root.new()
	# Root's editor-only _ready loads the deliberately excluded debug view.
	# Use its approved projection without entering that scene lifecycle.
	game_root.simulation = Controller.new()
	game_root.simulation.toggle_pause()
	get_root().content_scale_size = Vector2i(1920, 1080)
	get_root().size = Vector2i(1920, 1080)
	var frozen: Dictionary = game_root.simulation.run.to_dict()
	var signals: Array[Dictionary] = []
	for index: int in 6:
		signals.append({"id": "pack:%d" % index, "source_knowledge_id": "pack:%d" % index,
			"category": ["carbohydrate", "water", "protein", "nest_site", "threat", "threat"][index],
			"bearing": -1.1 + index * 0.42, "estimated_distance": 9.0, "uncertainty_radius": 2.0,
			"confidence": 0.8, "confidence_label": "clear", "strength": 0.8, "age": 10.0,
			"threat_kind": "ambush", "predator_profile": "wolf_spider" if index == 4 else "beetle_hunter" if index == 5 else ""})
	var view: Node2D = Outward.new()
	get_root().add_child(view)
	view.signal_provider = func() -> Array[Dictionary]: return signals
	view.status_provider = game_root.outward_status.bind("home")
	view._animation_time = 11.0
	for frame: int in 15: await process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_cmdline_user_args()[0]
	var picture: Image = get_root().get_texture().get_image()
	var failed: bool = picture.get_size() != Vector2i(1920, 1080) or picture.save_png(output) != OK
	failed = failed or view.chemical_field.clouds.size() != 6 or frozen != game_root.simulation.run.to_dict()
	print("[PACKED-CLOUDS] detached_six_materials_native=%s adapter=%s" % [not failed, RenderingServer.get_video_adapter_name()])
	view.signal_provider = Callable()
	view.status_provider = Callable()
	view.free()
	game_root.free()
	for frame: int in 4: await process_frame
	await create_timer(0.25).timeout
	quit(1 if failed else 0)
