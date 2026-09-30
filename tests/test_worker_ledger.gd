extends RefCounted

const Run = preload("res://src/core/run_state.gd")
const Ledger = preload("res://src/sim/colony/worker_ledger.gd")


func run(test: Object) -> bool:
	var state := Run.new()
	var home: PileState = state.colony.piles.home
	var ledger: WorkerLedger = home.workers
	test.check(home.position == Vector2(20, 20) and home.queen_count == 1 and home.workers_total == 40 and home.workers_available == 40, "Home fixture")
	for entry: Array in [["trail_a", "other", "route_a"], ["scouts", "scout", "mission_a"], ["care", "internal", "job_a"]]:
		test.check(ledger.create_commitment(entry[0], entry[1], entry[2]), "Explicit commitment")
	test.check(ledger.allocate("trail_a", 10) and ledger.allocate("scouts", 2) and ledger.allocate("care", 5), "Allocate disjoint workers")
	test.check(home.workers_available == 23 and home.workers_total == 40 and state.colony.workers_total == 40, "Derived counts")
	for args: Array in [["available", "trail_a", 24], ["trail_a", "available", 11], ["available", "care", -1], ["available", "care", 1.5], ["missing", "available", 1], ["available", "care", true]]:
		var before: Dictionary = ledger.to_dict()
		test.check(not ledger.transfer(args[0], args[1], args[2]) and before == ledger.to_dict() and not ledger.last_error.is_empty(), "Invalid transfer is atomic")
	var before_zero: Dictionary = ledger.to_dict()
	test.check(ledger.transfer("available", "care", 0) and ledger.to_dict() == before_zero, "Zero is no-op")
	test.check(ledger.release("trail_a", 10) and ledger.release("scouts", 2) and ledger.release("care", 5) and ledger.available == 40, "Actual returns restore availability")
	test.check(ledger.add_living_workers("available", 3, "Test maturation") and ledger.allocate("care", 2) and ledger.remove_living_workers("care", 1, "Test loss") and ledger.total == 42 and ledger.invariant_holds(), "Population accounting")
	var before_remove: Dictionary = ledger.to_dict()
	test.check(not ledger.remove_living_workers("care", 2, "Invalid loss") and ledger.to_dict() == before_remove, "Over-removal atomic")
	var rng := RandomNumberGenerator.new()
	rng.seed = 91027
	var pools: Array[String] = ["available", "trail_a", "scouts", "care"]
	for index: int in range(1000):
		var source: String = pools[rng.randi_range(0, 3)]
		var destination: String = pools[rng.randi_range(0, 3)]
		var amount: int = rng.randi_range(-2, 50)
		var before: Dictionary = ledger.to_dict()
		var expected: bool = amount >= 0 and amount <= ledger.count(source)
		var result: bool = ledger.transfer(source, destination, amount)
		test.check(result == expected and ledger.invariant_holds() and ledger.total == 42 and (result or ledger.to_dict() == before), "Deterministic ledger operation %d" % index)
	var restored := Ledger.new()
	test.check(restored.restore(JSON.parse_string(JSON.stringify(ledger.to_dict()))) and restored.to_dict() == ledger.to_dict(), "Populated ledger JSON round trip")
	var before_restore: Dictionary = restored.to_dict()
	var invalid: Dictionary = before_restore.duplicate(true)
	invalid.total += 1
	test.check(not restored.restore(invalid) and restored.to_dict() == before_restore, "Invalid ledger restore atomic")
	var detached: Dictionary = ledger.to_dict()
	detached.commitments.care.count = 900
	test.check(ledger.invariant_holds(), "Snapshot cannot mutate ledger")
	var restored_run := Run.new()
	test.check(restored_run.restore(JSON.parse_string(JSON.stringify(state.to_dict()))) and restored_run.to_dict() == state.to_dict(), "Populated pile and run round trip")
	var invalid_run: Dictionary = state.to_dict()
	invalid_run.colony.piles[0].workers.total += 1
	test.check(not restored_run.restore(invalid_run) and restored_run.to_dict() == state.to_dict(), "Invalid colony restore atomic")
	print("[COLONY] home=(20,20) queens=1 initial_workers=40; 1000 transfers conserved workers")
	return true
