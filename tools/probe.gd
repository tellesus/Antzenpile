extends SceneTree
## Prints how an untouched colony fares minute by minute. Used for tuning.
## Usage: godot --headless --path . --script res://tools/probe.gd

func _init() -> void:
	var w := SimWorld.new(20261113)
	for m in 10:
		for i in 600:
			w.step()
		var known := 0
		for v in w.colony.known_tick:
			if v >= 0.0:
				known += 1
		var connected := 0
		for i in w.colony.count:
			connected += w.colony.aconnected[i]
		print("min %d: agents %d  food %d  known %d%%  connected %d" % [
			m + 1, w.colony.count, int(w.colony.food_stored),
			known * 100 / (w.width * w.height), connected])
	quit(0)
