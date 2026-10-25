extends RefCounted
class_name DebrisQuantum

signal expired

const PARTICLE_COUNT := 4
const MIN_ALPHA := 0.15
const HALF := 0.5
const TAG := "quantum"

var debris : DebrisObject
var focus : Node2D
var time_left := 0.0
var is_armed := false
var phase := 0.0
var radius_squared := 0.0

func _init(owning_debris : DebrisObject) -> void:
	debris = owning_debris

# Starts the countdown state, tints the debris, and spawns the particle emitters.
func begin(focus_node : Node2D) -> void:
	debris.is_quantum = true
	debris.runtime_tags.append(TAG)
	focus = focus_node
	time_left = debris.data.quantum_lifetime
	radius_squared = debris.data.quantum_trigger_radius * debris.data.quantum_trigger_radius
	debris.modulate = debris.quantum_tint
	for particle_index in PARTICLE_COUNT:
		var emitter := debris.quantum_particle_scene.instantiate() as FXEmitter
		emitter.finished.connect(emitter.queue_free)
		debris.quantum_container.add_child(emitter)

# Clears all quantum state and removes leftover particle emitters.
func reset() -> void:
	debris.is_quantum = false
	debris.quantum_caught = false
	is_armed = false
	phase = 0.0
	focus = null
	debris.runtime_tags.erase(TAG)
	debris.modulate = Color.WHITE
	if debris.quantum_container:
		debris.quantum_container.top_level = false
		debris.quantum_container.position = Vector2.ZERO
		for emitter in debris.quantum_container.get_children():
			emitter.queue_free()

func is_spent() -> bool:
	return debris.is_quantum and (debris.quantum_caught or is_armed)

# Arms when the focus gets close, then flashes faster until it expires.
func tick(delta : float) -> void:
	if debris.quantum_caught:
		return
	if not is_armed:
		is_armed = is_instance_valid(focus) and debris.global_position.distance_squared_to(focus.global_position) <= radius_squared
		return
	time_left -= delta
	if time_left <= 0.0:
		_expire()
		return
	var elapsed_ratio := 1.0 - time_left / debris.data.quantum_lifetime
	phase += TAU * lerpf(debris.flash_rate_start, debris.flash_rate_end, elapsed_ratio) * delta
	debris.modulate = Color(debris.quantum_tint, lerpf(MIN_ALPHA, 1.0, HALF + HALF * sin(phase)))

# Bursts the particles where the debris expired, then notifies listeners.
func _expire() -> void:
	debris.is_quantum = false   # double expire guard
	debris.runtime_tags.erase(TAG)
	debris.modulate = Color.WHITE
	debris.quantum_container.top_level = true
	debris.quantum_container.global_position = debris.global_position
	for emitter in debris.quantum_container.get_children():
		(emitter as FXEmitter).play()
	expired.emit()