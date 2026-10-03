extends RefCounted

const Loader = preload("res://src/sim/world/world_loader.gd")
const World = preload("res://src/sim/world/world_state.gd")


func run(test: Object) -> bool:
	var loader := Loader.new()
	var world := loader.load_scenario()
	test.check(world != null, "Authored scenario loads: " + loader.last_error)
	if world == null:
		return false
	var other := loader.load_scenario()
	test.check(world.to_dict() == other.to_dict(), "Independent authored worlds are identical")
	test.check(world.nodes.size() == 8 and world.bounds == Rect2(0, 0, 40, 40), "Eight-node 40m fixture with shelter")
	var counts: Dictionary = {"carbohydrate": 0, "protein": 0, "water": 0, "nest_site": 0}
	for id: String in world.nodes:
		var node: WorldNodeState = world.nodes[id]
		counts[node.definition_id] += 1
		print("[WORLD] %s %s quantity=%.0f" % [id, node.position, node.quantity])
	test.check(counts == {"carbohydrate": 4, "protein": 2, "water": 1, "nest_site": 1}, "Expected resource categories")
	test.check(world.nodes.protein_picnic.quantity == 0.0 and not world.nodes.protein_picnic.active, "Temporary picnic protein begins unavailable")
	world.nodes.carb_exposed.quantity = 50.0
	world.nodes.carb_exposed.properties["test"] = [1]
	test.check(other.nodes.carb_exposed.quantity == 100.0 and other.nodes.carb_exposed.properties.is_empty(), "Runtime nodes are isolated")
	test.check(loader.load_scenario().nodes.carb_exposed.quantity == 100.0, "Authored definition remains unchanged")
	var snapshot: Dictionary = world.to_dict()
	# Generic properties use JSON number semantics, not GDScript int/float identity.
	var canonical: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	var restored := World.new()
	test.check(restored.restore(JSON.parse_string(JSON.stringify(snapshot)), Loader.definition_ids()), "World JSON round trip")
	test.check(JSON.parse_string(JSON.stringify(restored.to_dict())) == canonical, "World data preserved across JSON numeric representation")
	var before_invalid: Dictionary = restored.to_dict()
	for invalid_kind: String in ["duplicate", "definition", "position", "quantity", "terrain"]:
		var bad: Dictionary = snapshot.duplicate(true)
		match invalid_kind:
			"duplicate": bad.nodes.append(bad.nodes[0].duplicate(true))
			"definition": bad.nodes[0].definition_id = "missing"
			"position": bad.nodes[0].position = [99.0, 20.0]
			"quantity": bad.nodes[0].quantity = -1.0
			"terrain": bad.terrain[0].exposure = 2.0
		test.check(not restored.restore(bad, Loader.definition_ids()), "Reject " + invalid_kind)
		test.check(not restored.last_error.is_empty() and restored.to_dict() == before_invalid, "Invalid world is atomic with diagnostic")
	return true
