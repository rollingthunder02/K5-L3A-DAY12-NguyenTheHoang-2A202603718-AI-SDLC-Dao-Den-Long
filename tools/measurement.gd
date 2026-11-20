extends RefCounted


static func checkpoint(folder: String, name: String) -> bool:
	var marker := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
	if marker == null:
		return false
	marker.close()
	var deadline := Time.get_ticks_msec() + 5000
	while not FileAccess.file_exists(folder.path_join(name + ".ack")):
		if Time.get_ticks_msec() >= deadline:
			return false
		OS.delay_msec(2)
	return true


static func write_result(folder: String, data: Dictionary) -> bool:
	var output := FileAccess.open(folder.path_join("result.json"), FileAccess.WRITE)
	if output == null:
		return false
	return output.store_line(JSON.stringify(data))
