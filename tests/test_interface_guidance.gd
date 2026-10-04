extends RefCounted
const Copy = preload("res://src/presentation/interface_text.gd")
const Memory = preload("res://src/presentation/outward/source_memory.gd")
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Inward = preload("res://src/presentation/inward/inward_view.gd")

func run(test: Object) -> bool:
	var root := Root.new()
	root.simulation = Controller.new()
	var before: Dictionary = root.simulation.run.to_dict()
	var status: Dictionary = root.inward_status("home")
	test.check(status.brood_reserve == root.simulation.brood.remaining_food_reserve(root.simulation.run.colony.piles.home), "Displayed auto-brood reserve is actual remaining local demand")
	status.brood_reserve.carbohydrate = 999
	test.check(root.simulation.run.to_dict() == before, "Reserve summary is detached and read-only attention")
	status = root.inward_status("home")
	status.workers_available = 1
	status.workers_assignable = 1
	status.resources.carbohydrate = 0
	test.check(Copy.local_shortage(status, {"carbohydrate": 10}, 4) == "Need 3 more available workers", "Labor advisory uses home availability rather than total colony count")
	status.workers_available = 4
	status.workers_assignable = 4
	test.check(Copy.local_shortage(status, {"carbohydrate": 10}, 4) == "Need 10.0 more carbs", "Food advisory names the missing local quantity")
	var view := Inward.new()
	test.get_root().add_child(view)
	view._status = status
	view.selected_id = "nursery"
	view._status.nursery_occupied_space = view._status.nursery_brood_capacity
	test.check(not view._can_lay_brood() and not view._brood_block_reason().is_empty(), "Full Nursery retains an explanation for unavailable laying")
	test.check(view.activate_at(view._brood_rect().get_center()) and not view._feedback.is_empty() and root.simulation.run.to_dict() == before, "Blocked brood target absorbs input without a hidden mutation")
	var entry: Dictionary = {"knowledge_id": "known:water_01", "category": "water", "delivered_total": 5}
	var name: String = Memory.display_name(entry)
	entry.workers = 9; entry.age = 9999
	test.check(Memory.display_name(entry) == name and name.begins_with("Water #"), "Stable colony memory name does not depend on age, labor or browser position")
	test.check(Memory.receipt_label({"category": "water"}, 100) == "No delivery home yet", "Water without delivery is not called food")
	entry.receipt = {"last_at": 50, "first_at": 10, "last_amount": 5, "earlier_unrecorded": false}
	test.check(Memory.receipt_label(entry, 100).contains("5.0 water") and Memory.first_receipt_label(entry, 100).begins_with("First delivery"), "Receipt names resource and separates first/latest intake")
	entry.receipt.earlier_unrecorded = true
	test.check(Memory.first_receipt_label(entry, 100).begins_with("Records began"), "Incomplete legacy history does not invent first delivery")
	test.check(Copy.duration(-5) == "0s" and Copy.duration(65) == "1m 05s", "Elapsed times remain readable and nonnegative")
	test.check(Memory.defense_is_latest({"received_at": 100}, {"last_loss_time": 90}) and not Memory.defense_is_latest({"received_at": 100}, {"last_loss_time": 110}), "A later returned loss regains attention rather than being hidden beneath an older defense")
	view.free(); root.free()
	return true
