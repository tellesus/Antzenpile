extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Controls = preload("res://src/presentation/colony_controls.gd")
const Snapshot = preload("res://tests/test_guest.gd")

func run(test: Object) -> bool:
	var backyard := Controller.new(71)
	var garden := Controller.new(71,"garden_edge")
	var twin := Controller.new(71,"garden_edge")
	test.check(garden.run.scenario_id == "garden_edge" and garden.run.to_dict() == twin.run.to_dict(), "Requested authored setting starts reproducibly")
	test.check(garden.run.world.to_dict() != backyard.run.world.to_dict() and garden.run.knowledge.nodes.is_empty(), "Different hidden geography supplies no founding knowledge")
	test.check(garden.run.world.nodes.water_01.position != backyard.run.world.nodes.water_01.position and garden.run.world.nodes.aphid_01.position != backyard.run.world.nodes.aphid_01.position and garden.run.world.nodes.aphid_01.definition_id == backyard.run.world.nodes.aphid_01.definition_id, "Resource positions vary while stable aphid identity retains compatible producer ecology")
	var quantity: float = twin.run.world.nodes.water_01.quantity
	garden.run.world.nodes.water_01.quantity = 0
	test.check(twin.run.world.nodes.water_01.quantity == quantity, "Authored definitions produce isolated mutable worlds")
	var initial: Dictionary = garden.run.to_dict()
	test.check(not garden.start_new_run(71,"absent") and not garden.start_new_run(71,72) and garden.run.to_dict() == initial, "Unknown new-run settings reject atomically")
	garden.run.rain.phase = "raining" # Isolate paid-rain material rule; ordinary trials trigger it through traffic.
	garden.advance(100)
	test.check(garden.run.world.nodes.water_01.quantity > 0, "Rain physically refills the moved water source")
	var nectar: WorldNodeState = garden.run.world.nodes.carb_sheltered
	nectar.quantity = 0
	garden.advance(220)
	test.check(nectar.quantity > 0 and garden.run.knowledge.nodes.is_empty(), "Shared nectar event renews the alternate world without knowledge leakage")
	garden.advance(160)
	test.check(garden.run.world.nodes.protein_picnic.active and garden.run.world.nodes.protein_picnic.quantity > 0, "Authored temporary crumbs still appear in the second setting")
	var saved: Dictionary = Snapshot.new().snapshot(garden)
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.scenario_id == "garden_edge", "Save restoration keeps alternate setting identity")
	garden.advance(40)
	copy.advance(40)
	test.check(garden.run.to_dict() == copy.run.to_dict(), "Alternate physical events continue exactly after JSON restore")
	var root := Root.new()
	test.get_root().add_child(root)
	root.start_new_colony(71,"garden_edge")
	root.simulation.advance(50)
	test.check(root.start_new_colony(71).accepted and root.current_scenario() == "garden_edge" and root.simulation.run.to_dict() == twin.run.to_dict(), "Unspecified repeat retains the current authored world")
	var controls := Controls.new()
	controls.seed_provider = root.current_seed
	controls.scenario_provider = root.current_scenario
	controls.start_command = root.start_new_colony
	test.get_root().add_child(controls)
	var before: Dictionary = root.simulation.run.to_dict()
	controls.activate_at(controls.button_rect().get_center())
	test.check(controls.selected_scenario == "garden_edge", "Opening restart menu starts from the active setting")
	controls.activate_at(controls.scenario_rect().get_center())
	test.check(controls.selected_scenario == "roadside" and root.simulation.run.to_dict() == before, "Roadside can be selected without changing the active colony")
	controls.activate_at(controls.scenario_rect().get_center())
	test.check(controls.selected_scenario == "backyard_slice" and root.simulation.run.to_dict() == before, "Selecting a setting does not replace the colony before an explicit start")
	controls.activate_at(controls.choice_rect("repeat").get_center())
	test.check(root.current_scenario() == "backyard_slice" and root.current_seed() == 71, "Repeat action applies the selected world with the current seed")
	controls.free()
	root.free()
	return true
