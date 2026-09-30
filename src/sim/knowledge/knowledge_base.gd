class_name KnowledgeBase
extends RefCounted
## Only delivered evidence and time enter this boundary. Never query hidden truth.

const Known = preload("res://src/sim/knowledge/known_node.gd")
const CONFIG = preload("res://data/knowledge/default_knowledge.tres")
var nodes: Dictionary[String, KnownNode] = {}
var observations: Dictionary[String, Observation] = {}
var _received_at: Dictionary[String, float] = {}
var outcomes: Dictionary[String, Array] = {}
var last_error: String = ""


func consume(inbox: Dictionary[String, Observation], time: float) -> bool:
	if not is_finite(time) or time < 0:
		return _reject("Invalid delivery time")
	# Validate the entire batch before changing archive or inbox.
	for id: String in inbox:
		var evidence: Observation = inbox[id]
		if evidence == null or id != evidence.id or not _valid_evidence(evidence, time):
			return _reject("Invalid delivered evidence")
		if observations.has(id) and observations[id].to_dict() != evidence.to_dict():
			return _reject("Observation ID reused with different evidence")
	var ids: Array = inbox.keys()
	ids.sort()
	for id: String in ids:
		if not observations.has(id):
			observations[id] = inbox[id].detached_copy()
			_received_at[id] = time
			_rebuild_node(inbox[id].source_node_id)
			record_outcome(inbox[id].source_node_id, true, time, "scout")
	inbox.clear()
	last_error = ""
	return true


func record_outcome(source_id: String, available: bool, time: float, method: String) -> bool:
	if not nodes.has("known:" + source_id) or not method in ["scout", "trail"] or not is_finite(time) or time < 0:
		return _reject("Invalid source outcome")
	if not outcomes.has(source_id):
		outcomes[source_id] = []
	var history: Array = outcomes[source_id]
	if not history.is_empty() and time < history.back().time:
		return _reject("Source outcomes must be chronological")
	if not history.is_empty() and history.back().available == available:
		return true
	history.append({"time": time, "available": available, "method": method})
	if history.size() > 16:
		history.pop_front()
	last_error = ""
	return true


func temporal_hint(knowledge_id: String) -> Dictionary:
	if not nodes.has(knowledge_id):
		return {}
	var history: Array = outcomes.get(nodes[knowledge_id].source_node_id, [])
	var first_positive: float = -1.0
	var saw_gap: bool = false
	var interval: float = -1.0
	for entry: Dictionary in history:
		if entry.available:
			if saw_gap and first_positive >= 0.0:
				interval = entry.time - first_positive
			first_positive = entry.time
			saw_gap = false
		else:
			saw_gap = true
	if interval < 0.0:
		return {"label": "Earlier report only" if history.is_empty() or history.back().available else "Last return found empty", "possible_recurrence": false}
	return {"label": "May recur after ~%.0f s (uncertain)" % (roundf(interval / 25.0) * 25.0), "possible_recurrence": true}


static func _valid_evidence(evidence: Observation, time: float) -> bool:
	if evidence.id != evidence.scout_id + ":" + evidence.source_node_id or evidence.scout_id.is_empty() or evidence.source_node_id.is_empty() or evidence.origin_pile.is_empty() or evidence.definition_id.is_empty():
		return false
	for value: float in [evidence.first_observed_at, evidence.observed_at, evidence.uncertainty_radius, evidence.closest_distance]:
		if not is_finite(value) or value < 0:
			return false
	return evidence.estimated_position.is_finite() and evidence.uncertainty_radius > 0 and evidence.first_observed_at <= evidence.observed_at and evidence.observed_at <= time


func _rebuild_node(source_id: String) -> void:
	var node := Known.new()
	node.id = "known:" + source_id
	node.source_node_id = source_id
	node.first_observed_at = INF
	node.first_delivered_at = INF
	var selected: Observation
	var ids: Array = observations.keys()
	ids.sort()
	for id: String in ids:
		var evidence: Observation = observations[id]
		if evidence.source_node_id != source_id:
			continue
		node.evidence_ids.append(id)
		node.first_observed_at = minf(node.first_observed_at, evidence.first_observed_at)
		node.first_delivered_at = minf(node.first_delivered_at, _received_at[id])
		node.last_delivered_at = maxf(node.last_delivered_at, _received_at[id])
		if selected == null or _preferred(evidence, selected):
			selected = evidence
	node.definition_id = selected.definition_id
	node.estimated_position = selected.estimated_position
	node.uncertainty_radius = selected.uncertainty_radius
	node.last_observed_at = selected.observed_at
	node.selected_evidence_id = selected.id
	var baseline: float = CONFIG.confirmed_confidence if selected.proximity_confirmed else CONFIG.cue_confidence
	node.confidence = clampf(baseline / (1.0 + selected.uncertainty_radius / CONFIG.uncertainty_scale), 0.0, 1.0)
	nodes[node.id] = node


static func _preferred(candidate: Observation, current: Observation) -> bool:
	if candidate.observed_at != current.observed_at:
		return candidate.observed_at > current.observed_at
	if candidate.uncertainty_radius != current.uncertainty_radius:
		return candidate.uncertainty_radius < current.uncertainty_radius
	if candidate.proximity_confirmed != current.proximity_confirmed:
		return candidate.proximity_confirmed
	return candidate.id < current.id


func to_dict() -> Dictionary:
	var records: Array[Dictionary] = []
	var ids: Array = observations.keys()
	ids.sort()
	for id: String in ids:
		records.append({"evidence": observations[id].to_dict(), "received_at": _received_at[id]})
	var known: Array[Dictionary] = []
	ids = nodes.keys()
	ids.sort()
	for id: String in ids:
		known.append(nodes[id].to_dict())
	var history_records: Array[Dictionary] = []
	ids = outcomes.keys()
	ids.sort()
	for source_id: String in ids:
		history_records.append({"source_id": source_id, "visits": outcomes[source_id].duplicate(true)})
	return {"observations": records, "nodes": known, "outcomes": history_records}


func restore(data: Dictionary, validated_evidence: Dictionary[String, Observation], time: float) -> bool:
	if not is_finite(time) or time < 0 or not data.has_all(["observations", "nodes"]) or not data.observations is Array or not data.nodes is Array:
		return _reject("Malformed knowledge snapshot")
	var candidate := KnowledgeBase.new()
	for record: Variant in data.observations:
		if not record is Dictionary or not record.has_all(["evidence", "received_at"]) or not record.evidence is Dictionary or not record.evidence.has("id"):
			return _reject("Malformed archive record")
		var id: Variant = record.evidence.id
		if not id is String or not validated_evidence.has(id) or candidate.observations.has(id):
			return _reject("Unknown or duplicate archive evidence")
		if not _valid_evidence(validated_evidence[id], time) or not _matches_quantized_position(record.evidence, validated_evidence[id].to_dict()):
			return _reject("Archive evidence mismatch")
		if not typeof(record.received_at) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(record.received_at)) or record.received_at < validated_evidence[id].observed_at or record.received_at > time:
			return _reject("Invalid evidence delivery time")
		candidate.observations[id] = validated_evidence[id].detached_copy()
		candidate._received_at[id] = float(record.received_at)
	if candidate.observations.size() != validated_evidence.size():
		return _reject("Archive evidence mismatch")
	for evidence: Observation in candidate.observations.values():
		candidate._rebuild_node(evidence.source_node_id)
	var rebuilt_nodes: Array = candidate.to_dict().nodes
	if rebuilt_nodes.size() != data.nodes.size():
		return _reject("Known nodes disagree with their evidence")
	for index: int in rebuilt_nodes.size():
		if not data.nodes[index] is Dictionary or not _matches_quantized_position(data.nodes[index], rebuilt_nodes[index]):
			return _reject("Known nodes disagree with their evidence")
	var history_records: Variant = data.get("outcomes", [])
	if not history_records is Array:
		return _reject("Malformed source history")
	for record: Variant in history_records:
		if not record is Dictionary or not record.has_all(["source_id", "visits"]) or not record.source_id is String or not candidate.nodes.has("known:" + record.source_id) or candidate.outcomes.has(record.source_id) or not record.visits is Array or record.visits.is_empty() or record.visits.size() > 16:
			return _reject("Invalid source history")
		var visits: Array = []
		var previous_time: float = -1.0
		var previous_available: Variant = null
		for entry: Variant in record.visits:
			if not entry is Dictionary or not entry.has_all(["time", "available", "method"]) or not typeof(entry.time) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(entry.time)) or entry.time < 0 or entry.time > time or typeof(entry.available) != TYPE_BOOL or not entry.method in ["scout", "trail"]:
				return _reject("Invalid source visit")
			if entry.time < previous_time or entry.available == previous_available:
				return _reject("Nonchronological source visits")
			previous_time = float(entry.time)
			previous_available = entry.available
			visits.append(entry.duplicate(true))
		candidate.outcomes[record.source_id] = visits
	nodes = candidate.nodes
	observations = candidate.observations
	_received_at = candidate._received_at
	outcomes = candidate.outcomes
	last_error = ""
	return true


static func _matches_quantized_position(record: Dictionary, expected: Dictionary) -> bool:
	# JSON writes Vector2's float32 components as decimals; parsing can differ by
	# a last double-precision bit. Quantize that one field before exact comparison.
	if not record.has("estimated_position") or not record.estimated_position is Array or record.estimated_position.size() != 2:
		return false
	for value: Variant in record.estimated_position:
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	var comparable: Dictionary = record.duplicate(true)
	var position := Vector2(record.estimated_position[0], record.estimated_position[1])
	comparable.estimated_position = [position.x, position.y]
	return comparable == expected


func _reject(reason: String) -> bool:
	last_error = reason
	return false
