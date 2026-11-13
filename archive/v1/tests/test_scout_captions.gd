extends RefCounted
const Trace = preload("res://src/presentation/outward/scout_trace_visual.gd")
func run(test: Object) -> bool:
	var blocked: Array[Rect2] = [Rect2(80, 260, 120, 20)]
	var before: Array[Rect2] = blocked.duplicate()
	var at: Variant = Trace.caption_at(Vector2(140, 290), Vector2(60, 12), blocked, Rect2(24, 148, 536, 334))
	test.check(at != null and at.y > 290, "Scout caption moves below a resource label without moving its marker")
	test.check(blocked == before, "Caption search never changes its caller's label reservations")
	var rect := Rect2(at - Vector2(30, 12), Vector2(60, 16))
	test.check(not blocked[0].grow(3).intersects(rect), "Primary returned-resource caption keeps a readable separation")
	blocked.append(Rect2(80, 148, 120, 334))
	test.check(Trace.caption_at(Vector2(140, 290), Vector2(60, 12), blocked, Rect2(24, 148, 536, 334)) == null, "Crowded secondary caption can hide while selectable trace stays present")
	test.check(Trace.caption_at(Vector2(10, 290), Vector2(60, 12), [], Rect2(24, 148, 536, 334)) == null, "Caption never crosses the field edge or controls")
	return true
