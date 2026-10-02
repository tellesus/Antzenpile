extends RefCounted
const View = preload("res://src/presentation/outward/outward_view.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const Fixture = preload("res://tests/test_outward.gd")

func run(test: Object) -> bool:
	var view := View.new(); test.get_root().add_child(view)
	var signals: Array[Dictionary] = []
	for index: int in 12:
		var signal_data: Dictionary = Fixture.new().signal_at("crowd_%02d" % index,0.0)
		signal_data.foreign_contact = true
		signals.append(signal_data)
	view._signals = signals
	view.selected_id = "crowd_11"
	for size: Vector2 in [Vector2(1280,720),Vector2(900,600)]:
		view._placed = Panorama.project(signals,0,size)
		var before: Array[Dictionary] = view._placed.duplicate(true)
		view._prepare_signal_captions(size)
		var result: Dictionary = view._signal_labels.duplicate(true)
		test.check(result.has(view.selected_id) and result.size() < signals.size() and not result.is_empty(), "Selected caption wins bounded space; exhausted secondary labels are omitted")
		var rects: Array[Rect2] = []
		for id: String in result:
			var text_size: Vector2 = view._font.get_string_size(view._signal_caption(signals[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,13)
			var rect := Rect2(result[id] - Vector2(text_size.x * 0.5,text_size.y),text_size + Vector2(0,4))
			test.check(Rect2(24,148,size.x - 48,size.y - 266).encloses(rect) and not rects.any(func(other: Rect2): return other.grow(3).intersects(rect)), "Placed resource captions remain inside the field and separate")
			rects.append(rect)
		view._prepare_signal_captions(size)
		test.check(result == view._signal_labels and before == view._placed and before[0].signal == signals[0], "Caption layout is deterministic without changing clouds, knowledge or hit geometry")
		var picked: String = Panorama.pick(view._placed,view._placed[0].center)
		test.check(picked != "" and view._placed.size() == 12, "Suppressed labels leave all sensory markers selectable")
	# Both a browser and context reserve their actual drawing areas.
	view._signals = [Fixture.new().signal_at("panel",deg_to_rad(320))]
	view.selected_id = ""
	view.sources_open = true
	view._placed = Panorama.project(view._signals,0,Vector2(1280,720))
	view._prepare_signal_captions(Vector2(1280,720))
	test.check(view._caption_blocks.has(Rect2(24,148,308,396)), "Open source browser is reserved for resource and scout captions")
	view.sources_open = false; view.exploration_open = true
	view._prepare_signal_captions(Vector2(1280,720))
	test.check(view._caption_blocks.has(Rect2(24,148,308,266)), "Open exploration controls are reserved")
	# Edge text may hide, while geometry retains the original bearing and input target.
	view.exploration_open = false
	view._signals = [Fixture.new().signal_at("edge",-PI / 2)]
	view._placed = Panorama.project(view._signals,0,Vector2(900,600))
	view._prepare_signal_captions(Vector2(900,600))
	test.check(view._placed[0].center.x == 72 and Panorama.pick(view._placed,view._placed[0].center) == "edge", "Field-edge label handling cannot drag a sensory cloud or its hit target")
	view.free()
	return true
