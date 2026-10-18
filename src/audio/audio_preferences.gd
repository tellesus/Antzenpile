class_name AudioPreferences
extends RefCounted
## Player preference, outside RunState and colony save slots.

const DEFAULT_PATH: String = "user://audio_preferences.cfg"
var music: float = 1.0
var cues: float = 1.0
var last_error: String = ""

func set_level(category: String, value: Variant) -> bool:
	if category not in ["music", "cues"] or not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > 1:
		return false
	set(category, float(value))
	return true

func save_file(path: String = DEFAULT_PATH) -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music)
	config.set_value("audio", "cues", cues)
	var error: Error = config.save(path)
	last_error = "Could not save sound preferences" if error != OK else ""
	return error == OK

func load_file(path: String = DEFAULT_PATH) -> bool:
	var config := ConfigFile.new()
	var error: Error = config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		last_error = ""
		return true
	if error != OK:
		last_error = "Could not read sound preferences"
		return false
	var candidate := AudioPreferences.new()
	if not candidate.set_level("music", config.get_value("audio", "music", 1.0)) or not candidate.set_level("cues", config.get_value("audio", "cues", 1.0)):
		last_error = "Invalid sound preferences; existing levels retained"
		return false
	music = candidate.music
	cues = candidate.cues
	last_error = ""
	return true
