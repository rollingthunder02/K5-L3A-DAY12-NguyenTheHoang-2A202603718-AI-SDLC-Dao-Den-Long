extends RefCounted

const LIMIT := 10
const NAME_PATTERN := r'\A[A-Za-z0-9_]{3,12}\z'

var path: String


func _init(save_path: String) -> void:
	path = save_path


func entries() -> Array:
	if not FileAccess.file_exists(path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("entries") is Array:
		return []
	var result: Array = []
	for row: Variant in data.entries:
		if row is Dictionary and row.get("name") is String and row.get("score") is float \
				and row.get("nights_won") is float and row.get("achieved_at") is String and row.get("seed") is float:
			result.append(row)
	return result


func record(name: String, score: int, nights_won: int, seed_value: int) -> Error:
	if RegEx.create_from_string(NAME_PATTERN).search(name) == null:
		return ERR_INVALID_DATA
	var rows := entries()
	var achieved := Time.get_datetime_string_from_system(true) + "Z"
	var entry := {"name": name, "score": score, "nights_won": nights_won, "achieved_at": achieved, "seed": seed_value}
	var index := 0
	while index < rows.size() and (int(rows[index].score) > score or
			(int(rows[index].score) == score and String(rows[index].achieved_at) <= achieved)):
		index += 1
	rows.insert(index, entry)
	if rows.size() > LIMIT:
		rows.resize(LIMIT)
	var temp := ProjectSettings.globalize_path(path + ".tmp")
	var error := _write(temp, rows)
	if error != OK:
		return error
	return DirAccess.rename_absolute(temp, ProjectSettings.globalize_path(path))


func export_to(destination: String) -> Error:
	return _write(destination, entries())


func _write(destination: String, rows: Array) -> Error:
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	if not file.store_line(JSON.stringify({"entries": rows}, "\t")):
		return ERR_FILE_CANT_WRITE
	file.flush()
	return file.get_error()
