extends SceneTree
## Headless test runner.
## Usage: godot --headless --path . --script res://tests/run_tests.gd
## Runs every test_* method in every tests/test_*.gd and exits non-zero on failure.

var _checks := 0
var _failures := 0
var _current := ""


func _init() -> void:
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		var suite: Object = script.new()
		suite.set("t", self)
		for m in suite.get_method_list():
			var name: String = m["name"]
			if name.begins_with("test_"):
				_current = "%s:%s" % [f, name]
				suite.call(name)
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 or _checks == 0 else 0)


func check(condition: bool, message: String = "") -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL %s  %s" % [_current, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [message, actual, expected])
