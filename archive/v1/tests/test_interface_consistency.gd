extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const Rival = preload("res://tests/test_rival_counterplay.gd")
const Search = preload("res://tests/test_journey_investigation.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")

func run(test: Object) -> bool:
	var root:=Root.new();root.simulation=Rival.new().ready_game()
	var route: Dictionary=root.trail_summaries("home")[0]
	var status: Dictionary=root.outward_status("home")
	var frozen: Dictionary=root.simulation.run.to_dict()
	var draft:=ConflictPopover.new();draft.start_edit(route,status)
	test.check(draft.draft_kind=="gather" and draft.borrowing_copy().detail.contains("stay assigned") and not draft.goal_editable(route,status),"A rival draft explains retained gatherers and a fixed junction goal")
	for enabled: bool in [true,false]:
		draft.all_hands=enabled
		var copy: Dictionary=draft.borrowing_copy()
		test.check(ThemeDB.fallback_font.get_string_size(copy.title,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x<=284 and ThemeDB.fallback_font.get_string_size(copy.detail,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x<=284,"Rival consent and consequence fit the actual compact target")
	test.check(root.simulation.run.to_dict()==frozen,"Inspecting rival labor/goal/consent cannot recall the current front")
	root.simulation=Search.new().investigated_game();route=root.trail_summaries("home")[0];status=root.outward_status("home")
	draft.start_edit(route,status)
	test.check(draft.searching(route,status) and not draft.goal_editable(route,status) and draft.borrowing_copy().detail.contains("recalled from this trail"),"Unidentified search has a fixed defense goal and affected-trail recall explanation")
	root.simulation=Defense.new().ready_game();route=root.trail_summaries("home")[0];status=root.outward_status("home")
	draft.start_edit(route,status)
	test.check(draft.goal_editable(route,status),"A confirmed predator permits choosing Clear or Hunt before dispatch")
	assert(root.simulation.journey_response.defend("route_1",12))
	status=root.outward_status("home");draft.start_edit(route,status)
	test.check(not draft.goal_editable(route,status),"A real dispatched party's goal is information, not an editable proposal")
	root.free()
	var menu:=ColonyControls.new()
	test.check(menu.build_caption().contains(SaveBuild.current().trim_prefix("editor-").trim_prefix("windows-").left(8)) and ThemeDB.fallback_font.get_string_size(menu.build_caption(),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x<=328,"The menu identifies the current save build within its actual footer")
	for page: Dictionary in ColonyControls.GUIDE:
		for line: String in page.lines:test.check(ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x<=680,"Help guidance fits its supported panel")
	menu.free()
	for size: Vector2i in [Vector2i(900,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		var viewport:=SubViewport.new();viewport.size=size;test.get_root().add_child(viewport)
		var review:=RunReview.new();viewport.add_child(review)
		var bounds: Rect2=review.map_rect()
		for point: Vector2 in [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y),bounds.get_center()]:
			for radius: float in [0.0,bounds.size.x]:
				var label: Dictionary=review.map_caption(point,radius,"Spider-like ambusher")
				test.check(bounds.encloses(label.rect),"A review-zone label cannot spill into events/details at any map edge")
		var long_label: Dictionary=review.map_caption(bounds.end,0,"An intentionally very long local historical annotation ".repeat(8))
		test.check(bounds.encloses(long_label.rect) and long_label.text.ends_with("…"),"Long review labels are fitted inside the map")
		viewport.free()
	return true
