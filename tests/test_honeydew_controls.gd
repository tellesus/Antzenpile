extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")


func run(test: Object) -> bool:
	var game := Controller.new(3043)
	var root := Root.new()
	root.simulation = game
	test.check(root.outward_status("home").honeydew.is_empty() and not root.start_honeydew_tending("known:aphid_01").accepted, "Undiscovered producer has no normal-view identity or control")
	test.check(game.dispatch_scout("home", PI / 4.0), "Scout can find honeydew through ordinary search")
	for step: int in 1000:
		if game.run.knowledge.nodes.has("known:aphid_01"):
			break
		game.advance(0.25)
	if not game.run.knowledge.nodes.has("known:aphid_01"):
		test.check(false, "Scout returned honeydew evidence")
		root.free()
		return true
	var view: OutwardView = View.new()
	test.get_root().add_child(view)
	view.honeydew_start_command = root.start_honeydew_tending
	view.honeydew_stop_command = root.stop_honeydew_tending
	view.trail_create_command = root.create_trail_for
	view.trail_set_command = root.set_trail_target
	view.trail_recheck_command = root.recheck_trail
	view.investigate_command = root.investigate_known_source
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view.selected_id = "signal:known:aphid_01"
	test.check(view._is_honeydew(view._selected_signal()) and view._signal_title_for(view._selected_signal()) == "Honeydew trace" and view._status.honeydew.relationship == "unknown", "Returned scout evidence names the producer without revealing its condition")
	test.check(view._button_at(view._honeydew_button_rect().get_center()).is_empty(), "Protection is not offered before a loaded trail return")
	var before: Dictionary = game.run.to_dict()
	view._run_command("honeydew_start")
	test.check(game.run.to_dict() == before and not view._feedback.is_empty(), "Semantic command still rejects premature protection")
	test.check(game.create_trail("home", "known:aphid_01"), "Known producer accepts normal trail investment")
	var route: TrailRouteState = game.run.trails.routes.route_1
	for step: int in 800:
		if route.delivered_total > 0.0:
			break
		game.advance(0.25)
	if route.delivered_total <= 0.0:
		test.check(false, "Trail carried honeydew home")
		view.queue_free()
		root.free()
		return true
	view._status = root.outward_status("home")
	var protect: Rect2 = view._honeydew_button_rect()
	test.check(view._button_at(protect.get_center()) == "honeydew_start" and protect.size == Vector2(260, 44), "Loaded return offers a touch-sized Protect producers action")
	var worker_before: int = game.run.colony.piles.home.workers_available
	view._pointer_press(protect.get_center(), "mouse")
	test.check(game.run.honeydew.relationship == "tended" and game.run.colony.piles.home.workers_available == worker_before - 6 and view._feedback == "Producers protected", "Mouse control reserves protection workers")
	view._status = root.outward_status("home")
	test.check(view._button_at(protect.get_center()) == "honeydew_stop" and view._status.honeydew.protection_workers == 6 and not view._status.honeydew.has("condition") and not view._status.honeydew.has("output"), "Tended context shows committed labor without hidden biology or forecast")
	view._pointer_press(protect.get_center(), "touch")
	test.check(game.run.honeydew.relationship == "exploited" and game.run.colony.piles.home.workers_available == worker_before and view._feedback == "Protection withdrawn", "Touch control releases the same six workers")
	var start: Dictionary = root.start_honeydew_tending("known:aphid_01")
	test.check(start.accepted and root.stop_honeydew_tending("known:aphid_01").accepted, "Root semantic callbacks share controller validation")
	var pile: PileState = game.run.colony.piles.home
	var spare: int = pile.workers_available
	test.check(pile.workers.create_commitment("test_busy", "other", "test") and pile.workers.allocate("test_busy", spare - 5), "Fixture reserves other labor to exercise shortage")
	view._status = root.outward_status("home")
	view._pointer_press(protect.get_center(), "mouse")
	test.check(view._feedback == "Not enough workers to protect the producers" and game.run.honeydew.relationship == "exploited" and pile.workers.count("honeydew:home") == -1, "Insufficient labor gives a concise rejection without partial commitment")
	test.check(pile.workers.release("test_busy", spare - 5) and pile.workers.retire_commitment("test_busy"), "Fixture releases unrelated commitment")
	for size: Vector2 in [Vector2(1280, 720), Vector2(900, 600)]:
		var x: float = size.x - 300.0
		var protection := Rect2(x, 350, 260, 44)
		var trail := Rect2(x, 398, 260, 44)
		var investigate := Rect2(x, 444, 260, 44)
		var bottom_controls := Rect2(0, size.y - 104.0, size.x, 64)
		test.check(protection.end.x <= size.x and protection.end.y < trail.position.y and trail.end.y < investigate.position.y and investigate.end.y < bottom_controls.position.y, "Honeydew context actions fit above controls at %s" % size)
	view.queue_free()
	root.free()
	return true
