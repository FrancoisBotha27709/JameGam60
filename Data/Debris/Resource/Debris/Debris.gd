extends Resource
class_name Debris

enum Tag {
	NULL,
	PLASTIC,
	METAL,
	CEMENT,
	ASTEROID
}

@export_group("Debris")
@export var tag : Tag
@export var display_name : String
@export var description : String
@export var scene : PackedScene
@export var texture : Texture2D

@export_group("Stats", "stat_")
@export var stat_value : int = 1
@export var stat_weight : float = 1.0
@export var data_tags : Array[String] = []

@export_group("Quantum", "quantum_")
@export_range(0.0, 1.0, 0.01) var quantum_chance : float = 0.05
@export var quantum_multiplier : float = 3.0
@export var quantum_lifetime : float = 3.0
@export var quantum_trigger_radius : float = 500.0

@export_group("Rope", "rope_")
@export var rope_length : float = 80.0
@export var rope_width : float = 2.0
@export var rope_pull_strength : float = 8.0

@export_group("Drift", "drift_")
@export var drift_speed_min : float = 60.0
@export var drift_speed_max : float = 180.0
@export var drift_turn_rate : float = 2.0
@export var drift_spin_max : float = 3.0
@export var drift_attached_factor : float = 0.3
@export var drift_burst_interval_min : float = 0.6
@export var drift_burst_interval_max : float = 2.0
@export var drift_burst_strength : float = 1.0

@export_group("Light", "light_")
@export var light_preset : LightPreset
@export_range(0.0, 1.0, 0.01) var light_chance := 1.0

@export_group("Shadow", "shadow_")
@export var shadow_cast := true

func get_description() -> String:
	return description