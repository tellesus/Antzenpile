extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func run(test: Object) -> bool:
	var game:=Controller.new(3030,"garden_edge")
	game.advance(330)
	var frame: Dictionary=game.run.history.frames.back()
	var at: Vector2=game.run.predator.position()
	test.check(frame.ecology.predator.profile=="beetle_hunter" and Vector2(frame.ecology.predator.position[0],frame.ecology.predator.position[1]).distance_to(at)<0.00002 and at.distance_to(PredatorState.CONFIG.position)>1,"Physical samples capture the actual roaming profile/position rather than the old fixed ambusher")
	var earlier: Dictionary=frame.duplicate(true);game.advance(30)
	test.check(game.run.history.frames.back().ecology.predator.position!=earlier.ecology.predator.position,"Selecting older samples retains their own physical moving position")
	var copy:=Controller.new()
	test.check(copy.restore_snapshot(snapshot(game)) and copy.run.to_dict()==game.run.to_dict(),"New bounded ecology samples restore exactly")
	var root:=Root.new();root.simulation=game
	var known: Dictionary=root.outward_status("home")
	game.run.predator.motion.position=Vector2(36,30)
	test.check(root.outward_status("home")==known and game.review_snapshot().is_empty(),"Private motion and recorded truth never enter normal UI or an unfinished reveal")
	root.free()
	var roadside:=Controller.new(3030,"roadside")
	var checkpoints: Dictionary={650:["residue"],1500:[],2115:["ground"],2265:["link_residue","ground"],2400:["link_residue"],3000:[]}
	for seconds: int in checkpoints:
		while roadside.run.simulation_time<seconds:roadside.advance(minf(60,seconds-roadside.run.simulation_time))
		var context: Dictionary=roadside.run.history.frames.back().ecology
		var kinds: Array=[]
		for zone: Dictionary in context.zones:kinds.append(zone.kind)
		for required: String in checkpoints[seconds]:test.check(required in kinds,"Actual active footprint is captured at "+str(seconds)+": "+required)
		if seconds==1500 or seconds==3000:test.check("residue" not in kinds and "link_residue" not in kinds and "ground" not in kinds,"Expired or future footprints are absent in this physical sample")
	test.check(copy.restore_snapshot(snapshot(roadside)) and copy.run.to_dict()==roadside.run.to_dict(),"Sampled warning/pressure/connection zones preserve exact continuation")
	roadside.end_run();var ended: Dictionary=snapshot(roadside)
	var old: Dictionary=ended.duplicate(true)
	for index: int in old.history.frames.size():
		var value: Dictionary=JSON.parse_string(old.history.frames[index]);value.erase("ecology");old.history.frames[index]=JSON.stringify(value,"",true,true)
	test.check(copy.restore_snapshot(old) and copy.run.history.frames.all(func(value: Dictionary)->bool:return not value.has("ecology")),"Older physical samples keep genuine missing context rather than fabricated positions")
	var review:=RunReview.new();test.get_root().add_child(review);review.open(copy.review_snapshot())
	test.check(review.visible and copy.run.history.ended and not copy.start_brood("home"),"Old reveal remains ended and cannot resume ordinary play")
	for field: String in ["profile","point","radius","kind","phase","duplicate","shape"]:
		var bad: Dictionary=ended.duplicate(true)
		var value: Dictionary=JSON.parse_string(bad.history.frames.back())
		match field:
			"profile":value.ecology.predator.profile="invented"
			"point":value.ecology.predator.position=[1000,1000]
			"radius":value.ecology.predator.radius=0
			"kind":value.ecology.zones=[{"kind":"invented","position":[20,20],"radius":1,"phase":"active"}]
			"phase":value.ecology.zones=[{"kind":"ground","position":[20,20],"radius":6,"phase":"future"}]
			"duplicate":value.ecology.zones=[{"kind":"surface","position":[20,20],"radius":1,"phase":"active"},{"kind":"surface","position":[20,20],"radius":1,"phase":"active"}]
			"shape":value.ecology.extra=true
		bad.history.frames[-1]=JSON.stringify(value,"",true,true)
		var fresh:=Controller.new();var before: Dictionary=fresh.run.to_dict()
		test.check(not fresh.restore_snapshot(bad) and fresh.run.to_dict()==before,"Malformed physical sample rejects atomically: "+field)
	review.free()
	return true
