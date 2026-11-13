extends SceneTree
## Real-time Windows UI-command walk-through; not a human playtest.

const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const TIMEOUT_MSEC: int = 480000
var game_root: Node
var began: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_size(Vector2i(1280, 720))
	game_root = Root.new()
	get_root().add_child(game_root)
	var game: SimulationController = game_root.simulation
	game.restore_snapshot(Controller.new(3030).run.to_dict())
	if game_root._debug_view != null:
		game_root._debug_view.snapshot_provider = game.run.to_dict
	await process_frame
	beginning()
	var outward: OutwardView = game_root._outward_view
	outward._status = game_root.outward_status("home")
	outward.facing = 0.0
	outward._run_command("scout")
	outward.facing = PI
	outward._run_command("scout")
	if game.run.scouts.size() != 2:
		_failed("The initial UI scout controls did not dispatch both missions")
		return
	if not await _until(func() -> bool: return game.run.knowledge.nodes.has("known:carb_exposed") and game.run.knowledge.nodes.has("known:carb_sheltered")):
		return
	_mark("carbohydrate reports")
	for knowledge_id: String in ["known:carb_exposed", "known:carb_sheltered"]:
		if not _invest(outward, knowledge_id):
			_failed("Could not invest " + knowledge_id)
			return
	outward.facing = 2.0
	outward._run_command("scout")
	if not await _until(func() -> bool: return game.run.rain.phase == "raining"):
		return
	_mark("rain")
	game_root.set_mode("inward")
	var inward: InwardView = game_root._inward_view
	inward.selected_id = "food_exchange"
	await process_frame
	inward.activate_at(inward._develop_rect().get_center())
	if game.run.colony.piles.home.food_exchange_state != "developing":
		_failed("Food Exchange action did not start")
		return
	_mark("development started")
	if not await _until(func() -> bool: return game.run.knowledge.nodes.has("known:protein_01")):
		return
	_mark("protein report")
	game_root.set_mode("outward")
	if not _invest(outward, "known:protein_01"):
		_failed("Could not invest protein")
		return
	if not await _until(func() -> bool: return game.run.colony.piles.home.food_exchange_state == "developed"):
		return
	_mark("developed; second music layer")
	if not await _until(func() -> bool: return game.run.colony.piles.home.brood_matured_total == 8):
		return
	_mark("eight workers emerged")
	print("[TIMED] result=pass sim=%.2fs wall=%.2fs workers=%d routes=%d" % [game.run.simulation_time, float(Time.get_ticks_msec() - began) / 1000.0, game.run.colony.piles.home.workers_total, game.run.trails.routes.size()])
	await _finish(0)


func beginning() -> void:
	began = Time.get_ticks_msec()
	print("[TIMED] started seed=3030 speed=1x fps_cap=60")


func _invest(outward: OutwardView, knowledge_id: String) -> bool:
	outward._signals = game_root.sensory_snapshot("home")
	outward._status = game_root.outward_status("home")
	for signal_data: Dictionary in outward._signals:
		if signal_data.source_knowledge_id == knowledge_id:
			outward.selected_id = signal_data.id
			outward._run_command("trail_create")
			return game_root.simulation.run.trails.find_route("home", knowledge_id) != null
	return false


func _until(condition: Callable) -> bool:
	while not condition.call():
		if Time.get_ticks_msec() - began > TIMEOUT_MSEC:
			_failed("Timed run exceeded eight real minutes")
			return false
		await process_frame
	return true


func _mark(label: String) -> void:
	print("[TIMED] %s sim=%.2fs wall=%.2fs" % [label, game_root.simulation.run.simulation_time, float(Time.get_ticks_msec() - began) / 1000.0])


func _failed(reason: String) -> void:
	printerr("[TIMED] result=fail " + reason)
	_finish(1)


func _finish(code: int) -> void:
	get_root().remove_child(game_root)
	game_root.free()
	await create_timer(0.5).timeout
	quit(code)
