extends RefCounted
const Activity = preload("res://src/presentation/inward/colony_activity.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")

func stress() -> Dictionary:
	return {"nursery_occupied_space": 16, "nursery_care_capacity": 16, "trail_workers": 10000,
		"nursery_state": "developed", "humidity": {"carers": 4, "moisture": 35.0, "larval_rate": 0.75},
		"midden": {"revealed": true, "cleaners": 5, "burden": 30.0, "larval_rate": 0.5, "state": "developing", "progress": 0.4},
		"food_exchange_state": "developing", "food_exchange_progress": 15.0, "food_exchange_duration": 60.0,
		"guest": {"rejection_active": true},
		"brood": [{"count": 8, "stage": "larva", "nutrition": 0.7, "care": 1.0}, {"count": 8, "stage": "pupa", "nutrition": 1.0, "care": 0.5}]}

func run(test: Object) -> bool:
	var status: Dictionary = stress()
	var before: Dictionary = status.duplicate(true)
	var centers: Dictionary = View.positions(Vector2(1280,720))
	var ants: Array[Dictionary] = Activity.representatives(status, centers, 5.0)
	test.check(ants.size() <= Activity.MAX_ANTS and ants.size() > 4, "Busy network stays bounded while representing expanded work")
	var roles: Array[String] = []
	for ant: Dictionary in ants:
		if ant.role not in roles: roles.append(ant.role)
		test.check(ant.position.is_finite() and ant.direction.length_squared() > 0.0, "Known internal activity produces finite abstract placement")
	test.check(roles.size() == 6, "Nursing, circulation, cleanup, climate, excavation and rejection each remain visible")
	test.check(status == before and ants != Activity.representatives(status, centers, 6.0), "Decoration moves without mutating its detached summary")
	test.check(Activity.jobs({}).is_empty() and Activity.brood_stages({}).is_empty(), "Absent work and brood create no invented activity")
	status.midden.burden = 0.0
	test.check(Activity.jobs(status).filter(func(job): return job.role == "cleanup").is_empty(), "Staffed clean Midden creates no invented refuse traffic")
	test.check(Activity.brood_stages(status) == ["larva", "larva", "larva", "pupa", "pupa", "pupa"], "Two aggregate cohorts retain distinct stages within six glyphs")
	test.check(Activity.pressure(status, "nursery") == "DRY / REFUSE / FOOD / CARE", "Simultaneous known causes stay distinguishable")
	test.check(Activity.project_progress(status, "food_exchange") == 0.25 and Activity.project_progress(status, "midden") == 0.4, "Paid projects show normalized known progress")
	var game := Controller.new(67)
	var root := Root.new()
	root.simulation = game
	var view := View.new()
	test.get_root().add_child(view)
	view.status_provider = root.inward_status.bind("home")
	game.toggle_pause()
	var snapshot: Dictionary = game.run.to_dict()
	view._process(1.0)
	view._process(10.0)
	test.check(view._animation_time == 0.0 and game.run.to_dict() == snapshot, "Paused art leaves clock, worker ledger and RNG untouched")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = View.positions(view.get_viewport_rect().size).nursery
	view._unhandled_input(touch)
	test.check(view.selected_id == "nursery", "Enhanced Nursery retains the shared touch selection target")
	view.free()
	root.free()
	return true
