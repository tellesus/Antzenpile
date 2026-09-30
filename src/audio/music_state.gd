class_name MusicState
extends RefCounted
## Detached audio intent, derived from colony state. Never serialized as gameplay state.

var development_level: int = 0


static func from_food_exchange(state: String) -> MusicState:
	var result := MusicState.new()
	result.development_level = 1 if state == "developed" else 0
	return result
