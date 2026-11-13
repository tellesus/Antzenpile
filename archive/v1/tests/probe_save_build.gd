extends SceneTree
## Run in two separate processes to verify same-build persistence across restart.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	var game:=SimulationController.new(71)
	var service:=SaveService.new("res://.godot/card187-restart.json")
	var ok: bool=false
	if args[0]=="save":
		game.advance(20)
		ok=service.save(game.run)
	else:
		ok=service.load_into(game)
		var twin:=SimulationController.new(71)
		twin.advance(40);game.advance(20)
		ok=ok and game.run.to_dict()==twin.run.to_dict()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(service.path))
	print("[BUILD RESTART] ",args[0]," same_build_continuation=",ok," id=",SaveBuild.current())
	quit(0 if ok else 1)
