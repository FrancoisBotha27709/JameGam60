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

func _show(i : int) -> void:
	if i == current_image_index:
		return
	if sprite.texture is not CanvasTexture:
		sprite.texture = CanvasTexture.new()
	current_image_index = i
	var t := sprite.texture as CanvasTexture
	t.diffuse_texture = images[i].texture
	t.normal_texture = images[i].normal_map

func _show_f(v : float) -> void:
	_show(roundi(v))

func update_depot_sprite() -> void:
	if images.is_empty():
		return
	var n := images.size()
	var i := mini(int(DataCollector.get_quota_percentage() * n), n - 1)
	if current_image_index >= 0 and i > current_image_index:
		Audio.play("depot_fill", global_position)
	_show(i)

func reset_depot() -> void:
	if reset_tween:
		reset_tween.kill()
	if images.is_empty():
		return
	Audio.play("depot_reset", global_position)
	reset_tween = create_tween()
	reset_tween.tween_method(_show_f, float(maxi(current_image_index, 0)), 0.0, reset_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	reset_tween.tween_callback(func(): total_value = 0)

func _on_body_entered(body : Node2D) -> void:
	if body.is_in_group("Player"):
		if not body.attached_debris.is_empty():
			Audio.play("depot_deliver", global_position)
		body.deliver_to(self)
		fx_attach.play()