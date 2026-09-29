extends RefCounted

const Clock = preload("res://src/core/simulation_clock.gd")


func run(test: Object) -> bool:
	for speed: int in Clock.SCALES:
		var clock := Clock.new()
		var steps: Array[float] = []
		clock.tick.connect(func(delta: float) -> void: steps.append(delta))
		test.check(clock.set_time_scale(speed), "Supported speed accepted")
		clock.advance(1.0)
		test.check(clock.tick_count == speed * 4 and clock.simulation_time == speed, "One real second at %dx" % speed)
		test.check(steps.size() == speed * 4 and steps.all(func(d: float) -> bool: return d == 0.25), "Every emitted step stays fixed")
		clock.reset()
		clock.set_time_scale(speed)
		clock.advance(64.0 / speed)
		test.check(clock.tick_count == 256 and clock.simulation_time == 64.0, "Equal duration at %dx" % speed)
		print("[CLOCK] %dx: %d ticks / %.2fs" % [speed, clock.tick_count, clock.simulation_time])
	var clock := Clock.new()
	clock.advance(0.125)
	test.check(clock.tick_count == 0, "Fraction remains pending")
	clock.paused = true
	clock.advance(10.0)
	clock.paused = false
	clock.advance(0.125)
	test.check(clock.tick_count == 1 and clock.accumulator == 0.0, "Pause preserves only pre-pause fraction")
	for delta: float in [-1.0, INF, NAN]:
		test.check(not clock.advance(delta), "Invalid delta rejected")
	for speed: Variant in [0, -1, 2, 1.5, "4"]:
		test.check(not clock.set_time_scale(speed), "Invalid speed rejected")
	test.check(clock.tick_count == 1 and clock.time_scale == 1 and clock.accumulator == 0.0, "Rejected input is atomic")
	clock.reset()
	for i in range(8):
		clock.advance(0.125)
	test.check(clock.tick_count == 4 and clock.simulation_time == 1.0, "Frame partitions agree")
	clock.advance(0.0)
	test.check(clock.tick_count == 4, "Zero does nothing")
	clock.reset()
	test.check(clock.tick_count == 0 and clock.accumulator == 0.0 and not clock.paused and clock.time_scale == 1, "Reset matches new clock")
	clock.advance(1025.0)
	test.check(clock.tick_count == 4096 and clock.accumulator == 1.0, "Catch-up budget retains backlog")
	clock.advance(0.25)
	test.check(clock.tick_count == 4101 and clock.accumulator == 0.0, "Next frame drains retained backlog")
	return true
