class_name ReturnedDiscovery
extends RefCounted
## Ephemeral presentation baseline of detached, home-delivered sensory identities.

var _known_ids: Dictionary[String, bool] = {}

func baseline(signals: Array[Dictionary]) -> void:
	_known_ids.clear()
	for record: Dictionary in signals: _known_ids[record.id] = true

func poll(signals: Array[Dictionary]) -> String:
	var labels: Array[String] = []
	var count: int = 0
	for record: Dictionary in signals:
		if _known_ids.has(record.id): continue
		_known_ids[record.id] = true
		count += 1
		var label: String = "food" if record.category == "carbohydrate" else "water" if record.category == "water" else "protein" if record.category == "protein" else "chemical"
		if label not in labels: labels.append(label)
	if count == 0: return ""
	labels.sort()
	return "New %s %s returned" % [" + ".join(labels), "trace" if count == 1 else "traces"]
