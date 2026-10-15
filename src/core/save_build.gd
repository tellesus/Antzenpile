class_name SaveBuild
extends RefCounted
## A build is runtime content, not a save-schema version or a documentation commit.
static var _cached: String = ""

static func current() -> String:
	if not _cached.is_empty():return _cached
	var packaged: String = ProjectSettings.get_setting("application/config/save_build_id", "")
	if not packaged.is_empty():
		_cached=packaged
		return _cached
	var files: Array[String] = ["res://project.godot"]
	for folder: String in ["src","data","scenes","assets"]:_collect("res://"+folder,files)
	files.sort()
	var rows: String="editor\n"+str(Engine.get_version_info().string)+"\n"
	for path: String in files:
		var digest: String=FileAccess.get_sha256(path)
		if digest.is_empty():return ""
		rows+=path.trim_prefix("res://")+"\t"+digest+"\n"
	_cached="editor-"+rows.sha256_text()
	return _cached

static func _collect(folder: String, files: Array[String]) -> void:
	for name: String in DirAccess.get_files_at(folder):files.append(folder.path_join(name))
	for name: String in DirAccess.get_directories_at(folder):_collect(folder.path_join(name),files)
