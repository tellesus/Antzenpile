extends SceneTree
## Measures simulation cost. Usage: godot --headless --path . --script res://tools/perf.gd

func _init() -> void:
	var w := SimWorld.new(20261113, 200, 200, Colony.MAX_ANTS)
	for i in 200:
		w.step()
	var t0 := Time.get_ticks_usec()
	var n := 300
	for i in n:
		w.step()
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("%d ants: %.2f ms per tick (budget 10 ms)" % [w.colony.count, ms])
	quit(0)
