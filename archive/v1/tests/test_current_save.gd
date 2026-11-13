extends RefCounted
const Mixed = preload("res://tests/test_save_load.gd")
const Parent = preload("res://tests/test_parent_supply.gd")
const Search = preload("res://tests/test_journey_investigation.gd")
const Root = preload("res://src/core/game_root.gd")
const SLOT: String = "res://.godot/card178-current-slot.json"

func round_trip(test: Object, game: SimulationController, label: String) -> void:
	var service := SaveService.new(SLOT)
	var root := Root.new()
	root.simulation = game
	root.save_service = service
	var before: Dictionary = game.run.to_dict().duplicate(true)
	var started: int = Time.get_ticks_usec()
	var saved: bool = root.quick_save().accepted
	var milliseconds: float = (Time.get_ticks_usec()-started)/1000.0
	test.check(saved and game.run.to_dict()==before, label+": current snapshot saves without changing live state")
	if not saved:
		print("[CURRENT SAVE] rejected ",label,": ",service.last_error)
		root.free()
		return
	var document: String = FileAccess.get_file_as_string(SLOT)
	var reference := SimulationController.new()
	test.check(service.load_into(reference) and reference.run.to_dict()==before, label+": exact serialized slot restores")
	test.check(root.end_run_review() and root.mode=="review" and not root.simulation.review_snapshot().is_empty(), label+": explicit end exposes review")
	var ended: Dictionary = game.run.to_dict().duplicate(true)
	var review: Dictionary = game.review_snapshot()
	review.history.frames.clear()
	test.check(game.run.to_dict()==ended and not game.advance(20), label+": detached review and paused ending cannot mutate the run")
	test.check(not root.quick_save().accepted and FileAccess.get_file_as_string(SLOT)==document, label+": ended review cannot replace the saved unrevealed colony")
	test.check(root.quick_load().accepted and root.mode=="outward" and root.simulation.run.to_dict()==before, label+": load returns to the saved unrevealed state")
	for step: int in 80:
		root.simulation.advance(0.25)
		reference.advance(0.25)
	test.check(root.simulation.run.to_dict()==reference.run.to_dict(), label+": continued state matches the unrevealed reference exactly")
	print("[CURRENT SAVE] ",label," bytes=",document.to_utf8_buffer().size()," validation_and_write_ms=",snappedf(milliseconds,0.01))
	root.free()

func run(test: Object) -> bool:
	for scenario: String in ScenarioCatalog.IDS:
		round_trip(test,SimulationController.new(71,scenario),"fresh "+scenario)
	round_trip(test,Mixed.new()._fixture(),"rain, cargo, scouts and chamber work")
	var daughter: SimulationController = Parent.new().fixture()
	assert(daughter.set_daughter_supply(true))
	daughter.advance(0.25)
	round_trip(test,daughter,"two nests with paid cargo outbound")
	var search: SimulationController = Search.new().investigated_game()
	assert(search.journey_response.set_force("route_1",12))
	var seen: Dictionary = {}
	for tick: int in 2400:
		var phase: String = search.run.journey_response.phase
		if not seen.has(phase):
			seen[phase]=true
			var copy := SimulationController.new()
			assert(copy.restore_snapshot(JSON.parse_string(JSON.stringify(search.run.to_dict(),"",true,true))))
			round_trip(test,copy,"armed search "+phase)
		if not search.run.journey_response.active() and seen.has("outbound"):break
		search.advance(0.25)
	test.check(seen.has_all(["outbound","fighting","inbound","idle"]),"Current-build disk checks cover armed departure, private combat, returning witness and delivered result")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT))
	return true
