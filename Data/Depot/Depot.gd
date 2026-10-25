extends Area2D
class_name Depot

@export var fx_attach : FXEmitter
## Asteroid edges are never allowed closer than this to the depot centre.
@export var asteroid_clearance : float = 500.0
@export var sprite : Sprite2D
@export var images : Array[DepotImage]
@export var reset_duration : float = 0.25

var total_value : int = 0
var current_image_index : int = -1
var reset_tween : Tween

func _ready() -> void:
	add_to_group("Depot")
	body_entered.connect(_on_body_entered)
	update_depot_sprite()

func change_to_next_png(item_value : int) -> void:
	total_value += item_value
	update_depot_sprite()

func update_depot_sprite() -> void:
	if images.is_empty():
		return
	if sprite.texture is not CanvasTexture:
		sprite.texture = CanvasTexture.new()

	var quota : float = DataCollector.get_quota()

	if quota <= 0.0:
		return
	
	# Determine how full it should be
	var progress : float = clampf(DataCollector.score / quota, 0.0, 1.0)

	# Convert progrss to index
	var stage_count : int = images.size()
	var new_index : int = mini(int(progress * stage_count), stage_count - 1)
	if new_index == current_image_index:
		return
	
	current_image_index = new_index

	var depot_image : DepotImage = images[current_image_index]

	sprite.texture.diffuse_texture = depot_image.texture
	sprite.texture.normal_texture = depot_image.normal_map	

func reset_depot() -> void:
	if reset_tween and reset_tween.is_running():
		reset_tween.kill()

	reset_tween = create_tween()
	reset_tween.set_trans(Tween.TRANS_QUAD)
	reset_tween.set_ease(Tween.EASE_IN)

	for i in range(current_image_index - 1, -1, -1):
		reset_tween.tween_callback(func():
			current_image_index = i
			sprite.texture.diffuse_texture = images[i].texture
			sprite.texture.normal_texture = images[i].normal_map
		)
		reset_tween.tween_interval(reset_duration / maxf(current_image_index, 1))

	reset_tween.tween_callback(func():
		current_image_index = 0
		sprite.texture.diffuse_texture = images[0].texture
		sprite.texture.normal_texture = images[0].normal_map
		total_value = 0
	)

func _on_body_entered(body : Node2D) -> void:
	if body.is_in_group("Player"):
		body.deliver_to(self)
		fx_attach.play()