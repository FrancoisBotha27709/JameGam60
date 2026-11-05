@tool
extends EditorScript

const OUT_DIR := "res://Assets/lighting/Presets/"
const ONLY := ["debris_plastic", "debris_metal", "debris_cement"]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var lib = LightPreset.library()
	var saved := 0
	for key in ONLY:
		if not lib.has(key):
			continue
		var p : LightPreset = lib[key].call()
		var err := ResourceSaver.save(p, OUT_DIR + key + ".tres")
		if err == OK:
			saved += 1
	EditorInterface.get_resource_filesystem().scan()