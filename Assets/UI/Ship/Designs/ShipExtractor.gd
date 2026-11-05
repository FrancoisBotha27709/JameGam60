@tool
extends EditorScript
class_name ShipExtractor

const DIR := "res://Assets/UI/Ship/Designs/"

func _run() -> void:
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with("_diffuse.png"):
			continue
		var base := file.trim_suffix("_diffuse.png")
		var normal_path := DIR + base + "_normal.png"
		var design := ShipDesign.new()
		design.ship_name = base.capitalize()
		design.diffuse_texture = load(DIR + file)
		if ResourceLoader.exists(normal_path):
			design.normal_texture = load(normal_path)
		ResourceSaver.save(design, DIR + base + ".tres")
	EditorInterface.get_resource_filesystem().scan()