extends SceneTree

const Root = preload("res://src/core/game_root.gd")
const Fixture = preload("res://tests/test_guest.gd")
var game_root: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game_root = Root.new()
	get_root().add_child(game_root)
	var game: SimulationController = Fixture.new().loss_fixture()
	game.start_guest_rejection()
	for tick: int in 240:
		if game.run.guest.phase == "purged":
			break
		game.advance(0.25)
	assert(game_root.simulation.restore_snapshot(Fixture.new().snapshot(game)))
	game_root.set_mode("inward")
	game_root._inward_view.selected_id = "guest"
	var simulation: SimulationController = game_root.simulation
	await _capture("quiet")
	Fixture.new().until_tick(simulation, simulation.run.guest.next_entry_tick)
	assert(game_root.guest_summary("home").reported_losses == 0)
	await _capture("fresh_entry")
	simulation.advance(60)
	await _capture("uncertain_loss")
	simulation.advance(60)
	await _capture("foreign_loss")
	var view: InwardView = game_root._inward_view
	view._status = game_root.inward_status("home")
	assert(view.activate_at(view._guest_rect().get_center()))
	assert(simulation.run.colony.piles.home.workers.count("rejection:home") == 4)
	await _capture("rejection")
	print("[GUEST-PROBE] ten standard/compact recurring contexts; actual rejection pointer command")
	game_root.queue_free()
	await process_frame
	quit()


func _capture(label: String) -> void:
	game_root.simulation.run.clock.paused = true
	var before: Dictionary = game_root.simulation.run.to_dict()
	for size: Vector2i in [Vector2i(1280,720), Vector2i(900,600)]:
		DisplayServer.window_set_size(size)
		for frame: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image = get_root().get_texture().get_image()
		assert(picture.save_png("res://.godot/card059_%s_%d.png" % [label, size.x]) == OK)
	assert(game_root.simulation.run.to_dict() == before)
	game_root.simulation.run.clock.paused = false
