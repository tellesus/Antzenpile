class_name AudioSettings
extends Node2D
var activation:=preload("res://src/presentation/activation_feedback.gd").new()

const UIStyle = preload("res://src/presentation/organic_ui.gd")
## Shared presentation overlay. Modal input never reaches colony controls.

var preferences: AudioPreferences
var changed: Callable
var blocked: Callable
var interaction_started: Callable
var opened: bool = false
var feedback: String = ""
var _font: Font = ThemeDB.fallback_font

func _ready() -> void:
	activation.attach(self,func() -> bool: return blocked.is_valid() and blocked.call())

func _process(_delta: float) -> void: queue_redraw()

func button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 328, 78, 100, 64)

func panel_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 432, 156, 408, 308)

func level_rect(category: String, index: int) -> Rect2:
	return Rect2(panel_rect().position + Vector2(32 + index * 68, 88 if category == "music" else 182), Vector2(60, 44))

func close_rect() -> Rect2:
	return Rect2(panel_rect().position + Vector2(32, 242), Vector2(332,44))

func activate_at(at: Vector2) -> bool:
	if blocked.is_valid() and blocked.call(): return false
	if button_rect().has_point(at):
		opened = not opened
		return true
	if not opened: return false
	if close_rect().has_point(at):
		opened = false
		return true
	for category: String in ["music", "cues"]:
		for index: int in 5:
			if level_rect(category, index).has_point(at):
				preferences.set_level(category, index * 0.25)
				feedback = "Saved locally" if not changed.is_valid() or changed.call() else "Applied; could not save locally"
	return true

func _input(event: InputEvent) -> void:
	if blocked.is_valid() and blocked.call(): return
	if opened and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		opened = false
		get_viewport().set_input_as_handled()
		return
	var press: bool = event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if press: activation.begin()
	if press and activate_at(event.position):
		activation.tap(event.position)
		if interaction_started.is_valid(): interaction_started.call()
		get_viewport().set_input_as_handled()
	elif opened:
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if preferences == null or blocked.is_valid() and blocked.call(): return
	UIStyle.surface(self, button_rect(), Color("18252b"))
	_label(button_rect().position + Vector2(25,38), "SOUND", 14, Color("d3dcd4"))
	if not opened: return
	draw_rect(get_viewport_rect(), Color(0.025,0.04,0.06,0.82))
	var panel: Rect2 = panel_rect()
	UIStyle.surface(self, panel, Color("111921"))
	UIStyle.surface(self, panel, Color("41535a"), true)
	_label(panel.position + Vector2(24,32), "Sound", 22, Color("d9d3be"))
	for category: String in ["music", "cues"]:
		_label(panel.position + Vector2(32,72 if category == "music" else 166), "Music" if category == "music" else "Information cues", 16, Color("a9b9bc"))
		for index: int in 5:
			var button: Rect2 = level_rect(category,index)
			UIStyle.surface(self, button, Color("355059") if preferences.get(category) == index * 0.25 else Color("263038"))
			_label(button.position + Vector2(9,28), "Off" if index == 0 else "%d%%" % (index * 25), 14, Color("dce5d9"))
	_label(panel.position + Vector2(32,235), feedback, 12, Color("82939c"))
	UIStyle.surface(self, close_rect(), Color("263038"))
	_label(close_rect().position + Vector2(142,28), "CLOSE", 14, Color("dce5d9"))

func _label(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
