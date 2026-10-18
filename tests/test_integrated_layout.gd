extends RefCounted
const Inward = preload("res://src/presentation/inward/inward_view.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
const Reports = preload("res://src/presentation/report_controls.gd")
const Audio = preload("res://src/audio/audio_controller.gd")

func run(test: Object) -> bool:
	for size: Vector2i in [Vector2i(900,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		var viewport := SubViewport.new(); viewport.size = size; test.get_root().add_child(viewport)
		var inward := Inward.new(); viewport.add_child(inward)
		var outward := Outward.new(); viewport.add_child(outward)
		var reports := Reports.new(); viewport.add_child(reports)
		var bounds := Rect2(Vector2.ZERO,Vector2(size))
		test.check(bounds.encloses(inward._pile_rect()) and not inward._pile_rect().intersects(reports.button_rect()),"Nest navigation has a separate on-screen header target")
		test.check(not outward._button_rect("pile").intersects(reports.button_rect()) and not outward._button_rect("pile").intersects(outward._button_rect("internal_pressure")),"OUTWARD Reports, other nest and local warning cannot cover each other")
		inward.selected_id = "nursery"
		inward._status = {"nursery_state":"developed"}
		var actions: Array[Rect2] = [inward._brood_rect(),inward._nursery_expand_rect(),inward._guest_link_rect()]
		for action: Rect2 in actions:
			test.check(bounds.encloses(action) and action.size.y >= 44,"Nursery commitments and harm navigation remain on-screen touch targets")
			for command: String in ["outward","pause","speed_1","speed_4","speed_16","speed_64"]:
				test.check(not action.intersects(inward._button_rect(command)) and not action.intersects(inward._pile_rect()),"Nursery actions do not overlap persistent navigation/time controls")
		for index: int in actions.size():
			for other: int in range(index+1,actions.size()): test.check(not actions[index].intersects(actions[other]),"Brood, expansion and harm keep distinct commitments")
		viewport.free()
	var audio := Audio.new(); test.get_root().add_child(audio)
	audio.stop_playback(); audio.stop_playback(); audio.restart_after_load()
	test.check(audio.music_player.stream == null and not audio.music_player.playing,"Shutdown is idempotent and reload cannot restart released audio")
	audio.free()
	return true
