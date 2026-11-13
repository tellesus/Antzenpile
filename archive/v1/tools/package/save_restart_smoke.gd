extends SceneTree
## Two separate unchanged-PCK processes share only an isolated current-build slot.
func _initialize() -> void:
	var service=load("res://src/core/save_service.gd").new("user://saves/restart187.json")
	var game=load("res://src/core/simulation_controller.gd").new(71)
	var mode: String=OS.get_cmdline_user_args()[0]
	var ok: bool=false
	if mode=="save":
		game.advance(20);ok=service.save(game.run)
	else:
		ok=service.load_into(game)
		var twin=load("res://src/core/simulation_controller.gd").new(71)
		twin.advance(40);game.advance(20)
		ok=ok and game.run.to_dict()==twin.run.to_dict()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(service.path))
	var identity: String=ProjectSettings.get_setting("application/config/save_build_id", "")
	ok=ok and identity.begins_with("windows-")
	print("[PACKED BUILD RESTART] ",mode," same_build_continuation=",ok," id=",identity)
	quit(0 if ok else 1)
