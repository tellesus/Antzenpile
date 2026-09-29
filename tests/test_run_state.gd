extends RefCounted

const Run = preload("res://src/core/run_state.gd")


func run(test: Object) -> bool:
	var a := Run.new(482817)
	var b := Run.new(482817)
	var other := Run.new(42)
	var differs: bool = false
	for i in range(100):
		var draw: int = a.rng.randi()
		test.check(draw == b.rng.randi(), "Same seed repeats draw %d" % i)
		differs = differs or draw != other.rng.randi()
	test.check(differs, "Different seeds have different sequences")
	var before: Dictionary = b.to_dict()
	a.clock.advance(0.375)
	a.rng.randi()
	test.check(b.to_dict() == before, "Independent runs share no clock/RNG state")
	var original := Run.new(482817)
	var fresh := Run.new(482817)
	test.check(original.rng.randi() == fresh.rng.randi(), "New run reproduces initial draw")
	for i in range(20):
		original.rng.randi()
	original.clock.advance(0.375)
	original.clock.set_time_scale(4)
	var saved: Dictionary = original.to_dict()
	# Exercise the actual lossless JSON boundary, not only an in-memory clone.
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var restored := Run.new(9)
	test.check(restored.restore(decoded), "Snapshot restores after JSON round trip")
	for i in range(100):
		test.check(original.rng.randi() == restored.rng.randi(), "RNG continuation matches")
		original.clock.advance(0.0625)
		restored.clock.advance(0.0625)
	test.check(original.to_dict() == restored.to_dict(), "All authoritative state matches after continuation")
	saved.clock.remainder = 999.0
	test.check(original.clock.accumulator != 999.0, "Snapshot is detached")
	before = restored.to_dict()
	var bad: Dictionary = before.duplicate(true)
	bad.version = 99
	test.check(not restored.restore(bad) and restored.to_dict() == before, "Unsupported snapshot is atomic")
	bad = before.duplicate(true)
	bad.clock.time = -1.0
	test.check(not restored.restore(bad) and restored.to_dict() == before, "Inconsistent time is atomic")
	bad = before.duplicate(true)
	bad.rng_state = "9223372036854775808"
	test.check(not restored.restore(bad) and restored.to_dict() == before, "Out-of-range RNG integer rejected")
	print("[RUN] seed=%d scenario=%s continuation matched" % [original.run_seed, original.scenario_id])
	return true
