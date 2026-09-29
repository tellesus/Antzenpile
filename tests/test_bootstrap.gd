extends RefCounted


func run(test: Object) -> bool:
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	test.check(scene != null, "Main scene loads")
	if scene == null:
		return false
	var main: Node = scene.instantiate()
	test.check(main != null, "Main scene instantiates")
	if main != null:
		test.get_root().add_child(main)
		test.check(main.is_inside_tree(), "Main enters the scene tree")
		main.free()
	test.check(InputMap.has_action("debug_world"), "Project input settings are loaded")
	test.check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Compatibility renderer is configured")
	return true
