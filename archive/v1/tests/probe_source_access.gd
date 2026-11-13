extends SceneTree
## Development-only ordinary-command audit of source exhaustion and recovery.

const Controller = preload("res://src/core/simulation_controller.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Controller.new(3030)
	var pile: PileState = game.run.colony.piles.home
	if not game.dispatch_scout("home", 0.0) or not game.dispatch_scout("home", -PI / 2.0):
		printerr("Could not dispatch audit scouts")
		quit(1)
		return
	if not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:carb_exposed") and game.run.knowledge.nodes.has("known:water_01"), 220.0):
		printerr("Audit scouts did not report carbohydrate and water")
		quit(1)
		return
	if not game.create_trail("home", "known:carb_exposed") or not game.create_trail("home", "known:water_01"):
		printerr("Could not invest audit routes")
		quit(1)
		return
	var water_route: TrailRouteState = game.run.trails.find_route("home", "known:water_01")
	var carb_route: TrailRouteState = game.run.trails.find_route("home", "known:carb_exposed")
	if not game.set_trail_workers(water_route.id, 20) or not game.set_trail_workers(carb_route.id, 15):
		printerr("Could not allocate audit labor")
		quit(1)
		return
	var depleted: bool = _until(game, func() -> bool: return water_route.status == "depleted", 800.0)
	print("[SOURCE-AUDIT] depleted=", depleted, " time=", game.run.simulation_time, " water_node=", game.run.world.nodes.water_01.quantity, " water_store=", pile.resources.water, " carb_store=", pile.resources.carbohydrate, " rain=", game.run.rain.phase, " reported=", game.run.knowledge.temporal_hint("known:water_01"))
	if not depleted:
		quit(1)
		return
	game.advance(600.0)
	print("[SOURCE-AUDIT] after_wait time=", game.run.simulation_time, " water_node=", game.run.world.nodes.water_01.quantity, " rain=", game.run.rain.phase, " trail=", water_route.status)
	if not game.investigate_known_source("home", "known:water_01") or not _until(game, func() -> bool: return game.run.scouts.is_empty(), 130.0):
		printerr("Known-source investigation did not return")
		quit(1)
		return
	print("[SOURCE-AUDIT] investigation=", game.run.knowledge.temporal_hint("known:water_01"), " node=", game.run.world.nodes.water_01.quantity)
	if not game.dispatch_scout("home", PI) or not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:carb_sheltered"), 220.0):
		printerr("Sheltered source could not be found")
		quit(1)
		return
	if not game.create_trail("home", "known:carb_sheltered") or not _until(game, func() -> bool: return game.run.rain.phase == "raining", 100.0):
		printerr("Sheltered traffic did not unlock rain")
		quit(1)
		return
	var before_rain: float = pile.resources.water
	game.advance(60.0)
	print("[SOURCE-AUDIT] rain_done time=", game.run.simulation_time, " water_node=", game.run.world.nodes.water_01.quantity, " water_store_gain=", pile.resources.water - before_rain, " rain=", game.run.rain.phase)
	if pile.resources.water - before_rain < 2.9 or not _low_water_case() or not _protein_case():
		quit(1)
		return
	quit(0)


func _low_water_case() -> bool:
	var game := Controller.new(3030)
	if not game.dispatch_scout("home", 0.0) or not game.dispatch_scout("home", -PI / 2.0):
		return false
	if not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:carb_exposed") and game.run.knowledge.nodes.has("known:water_01"), 220.0):
		return false
	if not game.create_trail("home", "known:carb_exposed") or not game.create_trail("home", "known:water_01"):
		return false
	var water_route: TrailRouteState = game.run.trails.find_route("home", "known:water_01")
	var carb_route: TrailRouteState = game.run.trails.find_route("home", "known:carb_exposed")
	if not game.set_trail_workers(water_route.id, 4) or not game.set_trail_workers(carb_route.id, 5):
		return false
	var initial_time: float = game.run.simulation_time
	game.advance(180.0 - initial_time)
	print("[SOURCE-AUDIT] low_water_labor time=", game.run.simulation_time, " source=", game.run.world.nodes.water_01.quantity, " store=", game.run.colony.piles.home.resources.water, " trail=", water_route.status)
	return game.run.world.nodes.water_01.quantity > 0.0 and water_route.status != "depleted"


func _protein_case() -> bool:
	var game := Controller.new(3030)
	var pile: PileState = game.run.colony.piles.home
	if not game.dispatch_scout("home", PI / 2.0) or not game.dispatch_scout("home", 0.0):
		printerr("Could not dispatch protein/carbohydrate scouts")
		return false
	if not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:protein_01") and game.run.knowledge.nodes.has("known:carb_exposed"), 220.0):
		printerr("Protein/carbohydrate scouts did not return starting sources")
		return false
	if not game.create_trail("home", "known:protein_01") or not game.create_trail("home", "known:carb_exposed"):
		printerr("Could not invest protein/carbohydrate routes")
		return false
	var route: TrailRouteState = game.run.trails.find_route("home", "known:protein_01")
	var carb_route: TrailRouteState = game.run.trails.find_route("home", "known:carb_exposed")
	if not game.set_trail_workers(route.id, 20) or not game.set_trail_workers(carb_route.id, 5):
		printerr("Could not allocate protein/carbohydrate labor")
		return false
	if not _until(game, func() -> bool: return route.status == "depleted", 800.0):
		printerr("Protein route did not deplete")
		return false
	print("[SOURCE-AUDIT] protein_depleted time=", game.run.simulation_time, " source=", game.run.world.nodes.protein_01.quantity, " store=", pile.resources.protein, " report=", game.run.knowledge.temporal_hint("known:protein_01"))
	if game.run.simulation_time < 450.0:
		game.advance(450.0 - game.run.simulation_time)
	print("[SOURCE-AUDIT] picnic_visible_in_truth time=", game.run.simulation_time, " quantity=", game.run.world.nodes.protein_picnic.quantity, " known=", game.run.knowledge.nodes.has("known:protein_picnic"))
	if not game.dispatch_scout("home", 0.0):
		printerr("Could not dispatch picnic scout")
		return false
	if not _until(game, func() -> bool: return game.run.knowledge.nodes.has("known:protein_picnic"), 140.0):
		printerr("Picnic scout did not return source evidence")
		return false
	print("[SOURCE-AUDIT] picnic_report time=", game.run.simulation_time, " source=", game.run.world.nodes.protein_picnic.quantity, " store_carb=", pile.resources.carbohydrate)
	if not game.create_trail("home", "known:protein_picnic"):
		printerr("Could not invest picnic route")
		return false
	var picnic_route: TrailRouteState = game.run.trails.find_route("home", "known:protein_picnic")
	if not game.set_trail_workers(picnic_route.id, 8):
		printerr("Could not allocate picnic labor")
		return false
	var before: float = pile.resources.protein
	if not _until(game, func() -> bool: return pile.resources.protein > before + 0.5, 140.0):
		printerr("Picnic route did not deliver protein: time=", game.run.simulation_time, " status=", picnic_route.status, " source=", game.run.world.nodes.protein_picnic.quantity, " carb=", pile.resources.carbohydrate)
		return false
	print("[SOURCE-AUDIT] picnic_delivered time=", game.run.simulation_time, " store_gain=", pile.resources.protein - before, " known=", game.run.knowledge.nodes.has("known:protein_picnic"))
	return true


func _until(game: SimulationController, predicate: Callable, limit_seconds: float) -> bool:
	for tick: int in roundi(limit_seconds / 0.25):
		if predicate.call():
			return true
		game.advance(0.25)
	return predicate.call()
