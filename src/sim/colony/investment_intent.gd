class_name InvestmentIntent
extends RefCounted
## Unfunded special investments only; paid cohorts have their existing owners.
var reproduction: bool=false
var priority: Array[String]=[]

func add(kind: String) -> void:
	if kind not in priority: priority.append(kind)
func remove(kind: String) -> void: priority.erase(kind)
func first() -> String: return priority[0] if not priority.is_empty() else ""
func to_dict() -> Dictionary: return {"reproduction":reproduction,"priority":priority.duplicate()}
func restore(data: Dictionary, adaptation: bool, queens: int, daughter: bool) -> bool:
	if data.size()!=2 or not data.has_all(["reproduction","priority"]) or not data.reproduction is bool or not data.priority is Array or data.priority.size()>2: return false
	var restored: Array[String]=[]
	for kind: Variant in data.priority:
		if not kind is String or kind not in ["adaptation","reproduction"] or kind in restored: return false
		restored.append(kind)
	if ("adaptation" in restored)!=adaptation or ("reproduction" in restored)!=data.reproduction or data.reproduction and (queens<1 or daughter): return false
	reproduction=data.reproduction;priority=restored
	return true
