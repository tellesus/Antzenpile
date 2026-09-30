class_name SaveService
extends RefCounted
## One local slot. Disk I/O and its envelope stay outside the headless simulation.

const DEFAULT_PATH: String = "user://saves/slot_1.json"
const FORMAT: String = "antzenpile-run"
const FILE_VERSION: int = 1
const MAX_FILE_BYTES: int = 4 * 1024 * 1024

var last_error: String = ""
var path: String


func _init(slot_path: String = DEFAULT_PATH) -> void:
	path = slot_path


func save(run: RunState) -> bool:
	if run == null:
		return _reject("No active run")
	var payload: String = JSON.stringify(run.to_dict(), "", true, true)
	var document: String = JSON.stringify({"format": FORMAT, "file_version": FILE_VERSION,
		"payload": payload, "sha256": payload.sha256_text()}, "", true, true)
	if document.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return _reject("Save exceeds slot size limit")
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return _reject("Could not create save folder")
	var temporary: String = absolute + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _reject("Could not open temporary save")
	file.store_string(document)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_string(temporary) != document:
		DirAccess.remove_absolute(temporary)
		return _reject("Temporary save verification failed")
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		DirAccess.remove_absolute(temporary)
		return _reject("Could not replace save slot")
	last_error = ""
	return true


func load_into(controller: SimulationController) -> bool:
	if controller == null:
		return _reject("No active run")
	if not FileAccess.file_exists(path):
		return _reject("No saved run in slot")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _reject("Could not open save slot")
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return _reject("Save exceeds slot size limit")
	var document: String = file.get_as_text()
	file.close()
	var outer_parser := JSON.new()
	if outer_parser.parse(document) != OK:
		return _reject("Save file is malformed")
	var envelope: Variant = outer_parser.data
	if not envelope is Dictionary or not envelope.has_all(["format", "file_version", "payload", "sha256"]):
		return _reject("Save file is malformed")
	if envelope.format != FORMAT or envelope.file_version != FILE_VERSION or not envelope.payload is String or not envelope.sha256 is String:
		return _reject("Unsupported save format or version")
	if envelope.payload.sha256_text() != envelope.sha256:
		return _reject("Save checksum does not match")
	var payload_parser := JSON.new()
	if payload_parser.parse(envelope.payload) != OK:
		return _reject("Save payload is malformed")
	var snapshot: Variant = payload_parser.data
	if not snapshot is Dictionary or not controller.restore_snapshot(snapshot):
		return _reject("Save state failed validation")
	last_error = ""
	return true


func _reject(message: String) -> bool:
	last_error = message
	return false
