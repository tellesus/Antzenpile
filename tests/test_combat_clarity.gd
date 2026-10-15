extends RefCounted
const Root = preload("res://src/core/game_root.gd")
const Defense = preload("res://tests/test_ambusher_defense.gd")
const Rival = preload("res://tests/test_rival_counterplay.gd")
const Popover = preload("res://src/presentation/outward/conflict_popover.gd")

func run(test: Object) -> bool:
	for pointer: String in ["mouse","touch"]:
		var root := Root.new(); root.simulation=Defense.new().ready_game()
		var game: SimulationController=root.simulation
		var pile: PileState=game.run.colony.piles.home
		pile.midden.revealed=true
		assert(game.sanitation.set_workers("home",4))
		assert(pile.workers.create_commitment("test:busy","internal","home"))
		assert(pile.allocate_workers("test:busy",pile.workers_assignable-1))
		var view := OutwardView.new(); test.get_root().add_child(view)
		view.signal_provider=root.sensory_snapshot.bind("home"); view.status_provider=root.outward_status.bind("home")
		view.journey_command=root.respond_to_journey
		view.selected_id="threat:route_1"; view._process(0)
		var frozen: Dictionary=game.run.to_dict()
		view._pointer_press(view._conflict_rect("conflict_send").get_center(),pointer)
		view._pointer_press(view._conflict_rect("draft_more_many").get_center(),pointer)
		test.check(view.conflict.amount==17 and game.run.to_dict()==frozen,"Combat +/-5 is free proposal editing for "+pointer)
		view.conflict.amount=3
		var plan: Dictionary=view.conflict.preview(view._conflict_route(),view._status)
		test.check(plan.total==3 and plan.sent==0 and plan.available==1 and not plan.additional,"Initial response separates proposed total from protected free labor")
		view._pointer_press(view._conflict_rect("draft_commit").get_center(),pointer)
		test.check(view._feedback.contains("3 ants ordered") and view._feedback.contains("3 still recruiting"),"Accepted queued receipt describes recruiting rather than arrival")
		test.check(pile.midden.cleaners==4 and pile.workers_available>=pile.brood_care_workers_required(),"Ordinary combat order preserves existing jobs and held care")
		view._process(0); view._run_conflict_command("conflict_send")
		plan=view.conflict.preview(view._conflict_route(),view._status)
		test.check(plan.waiting==3 and plan.reserved==1 and plan.total==3,"Reopening an initial queued response replaces its target without adding it twice")
		frozen=game.run.to_dict()
		view._pointer_press(view._conflict_rect("draft_all").get_center(),pointer)
		test.check(view.conflict.all_hands and game.run.to_dict()==frozen,"Permission to reduce jobs remains free until commit")
		view._pointer_press(view._conflict_rect("draft_commit").get_center(),pointer)
		test.check(game.run.journey_response.active() and game.run.journey_response.defense.sent==3 and pile.midden.cleaners==2,"One explicit All Hands order recruits only the missing two through cleanup owner")
		view._process(0); view._run_conflict_command("conflict_send")
		plan=view.conflict.preview(view._conflict_route(),view._status)
		test.check(plan.additional and plan.sent==3 and plan.total==3+plan.requested,"Reinforcement states its addition and resulting known total separately")
		game.end_run()
		frozen=game.run.to_dict(); view._run_conflict_command("draft_commit")
		test.check(view.conflict.editing and game.run.to_dict()==frozen,"Rejected stale commitment stays editable and changes nothing")
		view.free(); root.free()
	var root := Root.new(); root.simulation=Rival.new().ready_game()
	var route: Dictionary=root.trail_summaries("home")[0]
	var popover := Popover.new(); popover.start_edit(route,root.outward_status("home"))
	var plan: Dictionary=popover.preview(route,root.outward_status("home"))
	test.check(plan.additional and plan.total==route.allocated_workers+popover.amount,"Junction proposal adds gatherers instead of recalling the front")
	var result: Dictionary=root.respond_to_journey("gather_3",route.id)
	test.check(result.accepted and result.ordered_total==route.allocated_workers+3,"Gathering reinforcement receipt retains the expected existing front")
	root.free()
	for size: Vector2 in [Vector2(1920,1080),Vector2(1280,720),Vector2(900,600)]:
		popover.editing=true
		var positions: Dictionary=popover.layout(size)
		test.check(positions.buttons.draft_commit.size.x==positions.editor.size.x-24,"Combat has one full-width primary order")
		for command: String in positions.buttons:
			if command.begins_with("draft_"):
				test.check(positions.editor.encloses(positions.buttons[command]),"Every combat editor target fits inside the panel")
	return true
