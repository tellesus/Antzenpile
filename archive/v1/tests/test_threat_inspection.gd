extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Portrait = preload("res://src/presentation/outward/conflict_impression.gd")
const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")
const Popover = preload("res://src/presentation/outward/conflict_popover.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")


func run(test: Object) -> bool:
	var root := Root.new()
	root.simulation = Defense.new().ready_game()
	root.simulation.toggle_pause()
	var view := View.new()
	test.get_root().add_child(view)
	var signals: Array[Dictionary] = root.sensory_snapshot("home")
	var status: Dictionary = root.outward_status("home")
	view.signal_provider = func() -> Array[Dictionary]: return signals
	view.status_provider = func() -> Dictionary: return status
	view.selected_id = "threat:route_1"
	view._process(0)
	var portrait: ConflictImpression = view.conflict_impression
	var route: Dictionary = view._conflict_route()
	var frozen: Dictionary = root.simulation.run.to_dict()
	var delivered: Dictionary = Portrait.evidence(route, signals)
	test.check(portrait.visible and Cloud.appearance(delivered,false).identity=="wolf_spider", "Actual returned species evidence supplies the conflict portrait")
	test.check(portrait.clip_contents and portrait.mouse_filter==Control.MOUSE_FILTER_IGNORE, "The portrait clips its shader and cannot intercept mouse/touch controls")
	test.check(portrait.cloud.cloud_material.get_shader_parameter("impression_mask")==Cloud.MASKS.wolf_spider, "Native portrait material binds the delivered spider rather than a generic sketch")
	var clock: float = portrait.cloud.cloud_material.get_shader_parameter("visual_time")
	view._process(40)
	test.check(clock==portrait.cloud.cloud_material.get_shader_parameter("visual_time"), "Pause freezes the inspection shader as well as the field")
	status.paused=false
	for speed: int in [1,64]:
		status.speed=speed
		var before: float = view._animation_time
		view._process(0.05)
		test.check(is_equal_approx(view._animation_time-before,0.05), "Inspection motion stays decorative at simulation speed %d" % speed)
	status.paused=true
	for replacement: String in ["generic","weak","stale","surface","missing","other_route"]:
		signals.assign(root.sensory_snapshot("home"))
		for signal_data: Dictionary in signals:
			if signal_data.id!="threat:route_1": continue
			match replacement:
				"generic": signal_data.erase("predator_profile")
				"weak": signal_data.confidence=0.1
				"stale": signal_data.age=1800.0
				"surface": signal_data.threat_kind="surface"
				"missing": signal_data.category="unknown"
				"other_route": signal_data.id="threat:route_2"
		view._process(0)
		test.check(portrait.cloud.cloud_material.get_shader_parameter("recognition")==0.0, "Old report history cannot restore unsupported anatomy after "+replacement)
	signals.assign(root.sensory_snapshot("home"))
	view.selected_id="signal:"+route.destination_knowledge_id;view.journey_open=true;view._process(0)
	test.check(portrait.visible and portrait.cloud.cloud_material.get_shader_parameter("recognition")>0.0, "Source-route journey inspection uses the same projected report")
	view.journey_open=false;view._process(0)
	test.check(not portrait.visible and portrait.cloud.cloud_material.get_shader_parameter("recognition")==0.0, "Leaving conflict clears the previous image in the reused material")
	view.journey_open=true;view._process(0);view.reset_mission_visuals()
	test.check(not portrait.visible, "Pile/load visual reset clears the portrait immediately")
	view.effort_draft.opened=true;view._process(0)
	test.check(not portrait.visible, "A replacement effort panel cannot retain an overlaid creature")
	test.check(root.simulation.run.to_dict()==frozen, "Inspecting and replacing detached images cannot mutate the authoritative run or RNG")
	_check_copy_and_bounds(test)
	view.free();root.free()
	return true


func _check_copy_and_bounds(test: Object) -> void:
	var popover := Popover.new()
	for size: Vector2 in [Vector2(1920,1080),Vector2(1280,720),Vector2(900,600)]:
		for editing: bool in [false,true]:
			popover.editing=editing
			var positions: Dictionary=popover.layout(size)
			test.check(positions.bounds.encloses(positions.portrait) and positions.portrait.end.y<=positions.center.y+4, "The clipped impression stays inside its circle above report text at %s" % size)
			for value: String in ["Spider-like predator witnessed","Beetle-like hunter witnessed","Awaiting the party's report","Resistance remains strong","Alternate course established","Strange ground residue reported"]:
				var lines: Array[String]=Popover.summary_lines(value,12,positions.radius*2-18)
				test.check(" ".join(lines)==value and lines.size()<=2, "Report wording is preserved in at most two rows")
				for line: String in lines:
					test.check(ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<=positions.radius*2-18, "The actual returned report fits without an ellipsis")
