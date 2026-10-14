extends RefCounted

const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")


func run(test: Object) -> bool:
	var signal_data: Dictionary = {"id": "memory", "source_knowledge_id": "known:memory", "category": "threat",
		"threat_kind": "ambush", "strength": 0.3, "confidence": 0.75, "age": 10.0,
		"bearing": 0.0, "estimated_distance": 8.0, "uncertainty_radius": 3.0}
	test.check(Cloud.appearance(signal_data, false).identity.is_empty(), "A generic ambush has no invented species anatomy")
	signal_data.predator_profile = "wolf_spider"
	var fresh: Dictionary = Cloud.appearance(signal_data, false)
	test.check(fresh.identity == "wolf_spider" and fresh.recognition > 0.9, "A confident supported report can resolve into a spider memory")
	var preserved: Dictionary = signal_data.duplicate(true)
	Cloud.appearance(signal_data, false)
	test.check(signal_data == preserved, "Appearance cannot mutate its detached evidence")
	signal_data.age = 900.0
	var old: Dictionary = Cloud.appearance(signal_data, false)
	test.check(old.recognition < fresh.recognition and old.level < fresh.level, "Observation age fades an old threat without a new report")
	signal_data.age = 1800.0
	test.check(Cloud.appearance(signal_data, false).identity.is_empty(), "A stale report loses its recognizable anatomy")
	signal_data.age = 10.0
	signal_data.confidence = 0.2
	test.check(Cloud.appearance(signal_data, false).identity.is_empty(), "Weak certainty remains abstract even with a dated identity")
	signal_data.confidence = 0.75
	for kind: String in ["surface", "residue", "foreign", ""]:
		signal_data.threat_kind = kind
		test.check(Cloud.appearance(signal_data, false).identity.is_empty(), "Non-predator evidence cannot borrow a predator mask: " + kind)
	signal_data.threat_kind = "mixed"
	signal_data.predator_profile = "beetle_hunter"
	test.check(Cloud.appearance(signal_data, false).identity == "beetle_hunter", "Mixed returned evidence retains its actually witnessed beetle")
	signal_data.predator_profile = "unrecognized"
	test.check(Cloud.appearance(signal_data, false).identity.is_empty(), "Unsupported identities have no fallback creature")
	signal_data.category = "water"
	test.check(Cloud.appearance(signal_data, true).level == 0.0 and Cloud.appearance(signal_data, true).identity.is_empty(), "Reported empty sources have neither living cloud nor renewed object impression")
	var view := View.new()
	test.get_root().add_child(view)
	var signals: Array[Dictionary] = [signal_data]
	view.signal_provider = func() -> Array[Dictionary]: return signals
	view.status_provider = func() -> Dictionary: return {"paused": false}
	view._process(0.05)
	var first: ChemicalCloud = view.chemical_field.clouds.memory
	var clock: float = first.cloud_material.get_shader_parameter("visual_time")
	test.check(view.chemical_field.clouds.size() == 1 and clock == view._animation_time, "Visible cloud receives the owning view's decorative clock")
	view.status_provider = func() -> Dictionary: return {"paused": true}
	view._process(5.0)
	test.check(first.cloud_material.get_shader_parameter("visual_time") == clock, "Pausing freezes the actual shader uniform")
	signals.append(signal_data.duplicate(true))
	signals[1].id = "second"
	view._process(0.0)
	test.check(first.cloud_material != view.chemical_field.clouds.second.cloud_material, "Separate memories cannot overwrite one another's shader evidence")
	signal_data.category = "threat"
	signal_data.predator_profile = "wolf_spider"
	view._process(0.0)
	var recognized: float = first.cloud_material.get_shader_parameter("recognition")
	signal_data.erase("predator_profile")
	view._process(0.0)
	test.check(recognized > 0.0 and first.cloud_material.get_shader_parameter("recognition") == 0.0, "A new generic report cannot retain an older species in a reused material")
	view.facing = PI
	view._process(0.0)
	test.check(view.chemical_field.clouds.is_empty(), "Turning away retires all cloud instances and their evidence")
	view.facing = 0.0
	signals.clear()
	view._process(0.0)
	test.check(view.chemical_field.clouds.is_empty(), "Empty/load attention cannot retain stale species nodes")
	view.free()
	return true
