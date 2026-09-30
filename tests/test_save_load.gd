extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Service = preload("res://src/core/save_service.gd")
const Root = preload("res://src/core/game_root.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
const Inward = preload("res://src/presentation/inward/inward_view.gd")

const SLOT: String = "res://.godot/card021_test_slot.json"


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(SLOT, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _fixture() -> SimulationController:
	var game := Controller.new(3030)
	game.dispatch_scout("home", 0.0)
	game.dispatch_scout("home", PI)
	game.advance(100.0)
	if not game.create_trail("home", "known:carb_exposed") or not game.create_trail("home", "known:carb_sheltered"):
		return game
	for index: int in 240:
		if game.run.rain.phase == "raining":
			break
		game.advance(0.25)
	game.start_food_exchange("home")
	game.dispatch_scout("home", 2.0)
	game.advance(12.0)
	game.run.rng.state = 9223372036854775807
	return game


func run(test: Object) -> bool:
	var path: String = ProjectSettings.globalize_path(SLOT)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
	var service: SaveService = Service.new(SLOT)
	var empty := Controller.new()
	var empty_before: Dictionary = empty.run.to_dict()
	test.check(not service.load_into(empty) and service.last_error == "No saved run in slot" and empty.run.to_dict() == empty_before, "Missing slot reports error without changing live run")
	var game := _fixture()
	var source: Dictionary = game.run.to_dict()
	var private_reports: int = 0
	for scout: ScoutAgent in game.run.scouts.values():
		private_reports += scout.observations.size()
	var cargo: float = 0.0
	for cohort: TransitCohort in game.run.trails.cohorts.values():
		cargo += cohort.payload
	test.check(game.run.rain.phase == "raining" and game.run.colony.piles.home.food_exchange_state == "developing" and not game.run.scouts.is_empty() and private_reports > 0 and cargo > 0.0 and game.run.colony.piles.home.workers.invariant_holds(), "Fixture contains private evidence, in-flight cargo, chamber progress and active rain")
	test.check(source.rng_state == "9223372036854775807" and source.seed == "3030", "Run snapshot encodes large RNG and seed as decimal strings")
	# A stale sibling temp is replaced, then renamed away during the save.
	var temp_file: FileAccess = FileAccess.open(SLOT + ".tmp", FileAccess.WRITE)
	temp_file.store_string("stale temporary data")
	temp_file.close()
	test.check(service.save(game.run) and FileAccess.file_exists(SLOT) and not FileAccess.file_exists(SLOT + ".tmp") and service.last_error.is_empty(), "Save writes and atomically replaces a stale temporary sibling")
	var original_document: String = FileAccess.get_file_as_string(SLOT)
	var loaded := Controller.new()
	test.check(service.load_into(loaded) and loaded.run.to_dict() == source and loaded.run.colony.piles.home.workers.invariant_holds(), "Disk load recreates every authoritative field and conserves workers")
	for index: int in 100:
		game.advance(0.25)
		loaded.advance(0.25)
	test.check(game.run.to_dict() == loaded.run.to_dict(), "Saved run and reloaded run match after 100 fixed ticks")
	var updated: Dictionary = game.run.to_dict()
	test.check(service.save(game.run), "Existing slot can be replaced on Windows")
	var replacement := Controller.new()
	var replaced_ok: bool = service.load_into(replacement)
	test.check(replaced_ok and replacement.run.to_dict() == updated, "Loading after overwrite returns the latest run")
	var stable: Dictionary = replacement.run.to_dict()
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SLOT))
	envelope.file_version = 99
	_write(JSON.stringify(envelope))
	test.check(not service.load_into(replacement) and replacement.run.to_dict() == stable, "Unsupported disk version rejects without replacing live state")
	envelope = JSON.parse_string(original_document)
	envelope.payload = envelope.payload + " "
	_write(JSON.stringify(envelope))
	test.check(not service.load_into(replacement) and service.last_error == "Save checksum does not match" and replacement.run.to_dict() == stable, "Checksum mismatch rejects unchanged live state")
	var invalid: Dictionary = source.duplicate(true)
	invalid.trails.routes[0].segment_id = "missing_segment"
	var invalid_payload: String = JSON.stringify(invalid, "", true, true)
	_write(JSON.stringify({"format": Service.FORMAT, "file_version": Service.FILE_VERSION, "payload": invalid_payload, "sha256": invalid_payload.sha256_text()}))
	test.check(not service.load_into(replacement) and replacement.run.to_dict() == stable, "Well-formed but invalid route reference rejects before replacement")
	_write("not json")
	test.check(not service.load_into(replacement) and replacement.run.to_dict() == stable, "Malformed file rejects before replacement")
	_write(original_document)
	var root := Root.new()
	test.get_root().add_child(root)
	root.save_service = service
	test.check(root.quick_load().accepted and root.simulation.run.to_dict() == source and root.music_state("home").development_level == 0, "Headless GameRoot load refreshes semantic run state without graphics or audio")
	test.check(InputMap.has_action("save_run") and InputMap.has_action("load_run"), "Save and load have named keyboard actions")
	var outward: OutwardView = Outward.new()
	root.add_child(outward)
	root._outward_view = outward
	outward.save_command = root.quick_save
	outward.load_command = root.quick_load
	var outward_save: Rect2 = outward._button_rect("save")
	var outward_load: Rect2 = outward._button_rect("load")
	test.check(outward_save.size == Vector2(100, 64) and outward_load.size == Vector2(100, 64) and not outward_save.intersects(outward_load), "OUTWARD offers distinct touch-sized save and load targets")
	outward._pointer_press(outward_save.get_center(), "mouse")
	test.check(outward._feedback == "Run saved", "Mouse save uses the same semantic GameRoot path")
	root.simulation.advance(1.0)
	outward._pointer_press(outward_load.get_center(), "touch")
	test.check(outward._feedback == "Run loaded" and root.simulation.run.to_dict() == source, "Touch load replaces run and reports success")
	var inward: InwardView = Inward.new()
	root.add_child(inward)
	root._inward_view = inward
	inward.save_command = root.quick_save
	inward.load_command = root.quick_load
	var inward_save: Rect2 = inward._button_rect("save")
	var inward_load: Rect2 = inward._button_rect("load")
	test.check(inward_save.size == Vector2(100, 64) and inward_load.size == Vector2(100, 64) and not inward_save.intersects(inward_load), "INWARD offers distinct touch-sized save and load targets")
	test.check(inward.activate_at(inward_save.get_center()) and inward._feedback == "Run saved", "INWARD touch save shares the semantic path")
	root.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
	return true
