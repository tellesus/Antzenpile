extends RefCounted
## Detached diagnostic data only. Never owns a RunState or consumes its RNG.

var shown: bool = false
var selected_id: String = "home"
var snapshot: Dictionary = {}
var transform: Transform2D = Transform2D.IDENTITY


static func allowed(debug_build: bool, display_name: String) -> bool:
	return debug_build and display_name != "headless"


func refresh(data: Dictionary, viewport: Vector2) -> void:
	snapshot = data.duplicate(true)
	var bounds: Array = snapshot.world.bounds
	var scale_factor: float = maxf(0.01, minf((viewport.x * 0.61 - 48) / bounds[2], (viewport.y - 150) / bounds[3]))
	transform = Transform2D(Vector2(scale_factor, 0), Vector2(0, scale_factor), Vector2(24, 106) - Vector2(bounds[0], bounds[1]) * scale_factor)


func toggle() -> void:
	shown = not shown


func pick(screen_position: Vector2) -> void:
	if snapshot.is_empty() or not shown:
		return
	var world_position: Vector2 = transform.affine_inverse() * screen_position
	var threshold: float = 14.0 / transform.x.length()
	var closest: float = threshold
	selected_id = ""
	for entry: Dictionary in snapshot.colony.piles + snapshot.world.nodes:
		var distance: float = world_position.distance_to(Vector2(entry.position[0], entry.position[1]))
		if distance <= closest:
			selected_id = entry.id
			closest = distance


func selected() -> Dictionary:
	if snapshot.is_empty():
		return {}
	for entry: Dictionary in snapshot.colony.piles + snapshot.world.nodes:
		if entry.id == selected_id:
			return entry.duplicate(true)
	return {}
