extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
const Save = preload("res://src/core/save_service.gd")


func known_fixture() -> SimulationController:
	var game := Controller.new(3043)
	game.dispatch_scout("home", PI / 4.0)
	for tick: int in 1000:
		if game.run.knowledge.nodes.has("known:aphid_01"):
			break
		game.advance(0.25)
	return game


func run(test: Object) -> bool:
	var root := Root.new()
	root.simulation = Controller.new()
	var view: InwardView = View.new()
	test.get_root().add_child(view)
	view._status = root.inward_status("home")
	view.selected_id = "adaptation"
	view.adaptation_command = root.start_adaptation
	view.honeydew_command = root.set_honeydew_protection
	var before: Dictionary = root.simulation.run.to_dict()
	for trait_id: String in ["lean", "load"]:
		test.check(not view.activate_at(view._adaptation_rect(trait_id).get_center()) and root.simulation.run.to_dict() == before, "Overview cannot start either brood trial")
	test.check(Web.visible_nodes(view._status) == ["foraging", "lean", "load"] and Web.node_at(Web.positions(Vector2(1280,720)).honeydew, Vector2(1280,720), view._status) == "", "Initial web shows genetic fork without a hidden ecological leaf")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Web.positions(view.get_viewport_rect().size).lean
	view._unhandled_input(mouse)
	test.check(view.web_selection == "lean" and root.simulation.run.to_dict() == before, "Mouse selects a genetic leaf without buying or mutating gameplay")
	test.check(view._adaptation_rect("lean") == view._adaptation_rect("load"), "Selected genetic choices share one consistent action location")
	test.check(view.activate_at(view._adaptation_rect("lean").get_center()) and root.simulation.run.to_dict() == before and view._feedback.contains("space"), "Unavailable leaf action returns real Nursery rejection feedback")
	root.simulation = known_fixture()
	view._status = root.inward_status("home")
	test.check(Web.visible_nodes(view._status).has("honeydew") and view._status.honeydew.relationship == "unknown", "Scout-delivered producer evidence reveals an unestablished ecological leaf")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Web.positions(view.get_viewport_rect().size).honeydew
	view._unhandled_input(touch)
	test.check(view.web_selection == "honeydew", "Touch selects the observed ecological leaf")
	before = root.simulation.run.to_dict()
	test.check(not view.activate_at(view._honeydew_rect().get_center()) and root.simulation.run.to_dict() == before, "Observed-but-unharvested relationship cannot act or accidentally start genetic brood")
	test.check(root.simulation.create_trail("home", "known:aphid_01"), "Web relationship fixture harvests through an ordinary route")
	for tick: int in 800:
		if root.simulation.run.honeydew.relationship == "exploited":
			break
		root.simulation.advance(0.25)
	view._status = root.inward_status("home")
	var available: int = view._status.workers_available
	test.check(view._status.honeydew.relationship == "exploited" and view.activate_at(view._honeydew_rect().get_center()) and root.simulation.run.colony.piles.home.workers_available == available - 6, "Harvested relationship acts through real six-worker protection commitment")
	view._status = root.inward_status("home")
	test.check(view.activate_at(view._honeydew_rect().get_center()) and root.simulation.run.colony.piles.home.workers_available == available, "Web withdrawal uses the existing authoritative relationship command")
	var detached: Dictionary = root.inward_status("home")
	detached.honeydew.relationship = "tended"
	test.check(root.inward_status("home").honeydew.relationship == "exploited" and not detached.honeydew.has("condition") and not detached.honeydew.has("quantity") and not detached.honeydew.has("pulse_ticks"), "Relationship context is detached and excludes source reality")
	var remembered: Dictionary = root.inward_status("home")
	root.simulation.run.world.nodes.aphid_01.active = false
	root.simulation.run.world.nodes.aphid_01.quantity = 0.0
	test.check(root.inward_status("home") == remembered, "Physical producer depletion does not rewrite ecological memory or refresh the web")
	for size: Vector2 in [Vector2(1280,720), Vector2(900,600)]:
		var points: Dictionary = Web.positions(size)
		var ids: Array[String] = Web.visible_nodes(view._status)
		for id: String in ids:
			test.check(Web.node_at(points[id], size, view._status) == id and points[id].x + 44 <= size.x - 316 and points[id].y + 64 < size.y - 104, "Web leaf target/context/control separation: " + id)
			for other: String in ids:
				if id < other:
					test.check(points[id].distance_to(points[other]) > 88.0, "Web leaf hit targets do not overlap")
	test.check(view.activate_at(view._web_back_rect().get_center()) and view.selected_id == "" and view.web_selection == "foraging", "Back to Colony closes attention without leaving INWARD")
	var trial: Dictionary = root.inward_status("home")
	trial.adaptation_trial = {"adaptation_id": "lean"}
	test.check(Web.trait_state(trial, "lean") == "Growing trial brood" and Web.trait_state(trial, "load") == "Alternative", "Trial and alternative leaf states remain distinct")
	trial.adaptation_trial = {}
	trial.adaptation_repertoire = "lean"
	trial.adapted_workers = 7
	test.check(Web.trait_state(trial, "lean") == "Inherited · 7 expressed" and Web.trait_state(trial, "load") == "Alternative", "Partial surviving expression is visible without inventing new traits")
	root._inward_view = view
	root.save_service = Save.new("res://.godot/tests/web_attention.json")
	view.selected_id = "adaptation"
	view.web_selection = "honeydew"
	var saved: bool = root.quick_save().accepted
	var loaded: bool = root.quick_load().accepted
	test.check(saved and loaded and view.selected_id == "" and view.web_selection == "foraging", "Loading clears focused web selection through the normal save/load path")
	view.free()
	root.free()
	return true
