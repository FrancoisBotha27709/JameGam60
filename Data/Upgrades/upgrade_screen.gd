extends Control
class_name UpgradeScreen

@export_group("Nodes", "node_")
@export var node_card_container : HBoxContainer
@export var node_overlay : DitherVignette
@export var node_panel : Control
@export var node_title : Label
@export var node_sub : Label
@export var node_flash : ColorRect

@export var card_scene : PackedScene
@export var card_count : int = 3

@export_group("Vignette")
@export var vignette_tint : Color = Color(0.3, 0.85, 1.0)
@export_range(0.0, 1.0) var vignette_intensity : float = 0.3
@export var vignette_fade_time : float = 0.4

@export_group("Intro")
@export var window_open_time : float = 0.35
@export var title_slam_time : float = 0.4
@export var title_start_scale : float = 1.6
@export var calm_title_start_scale : float = 1.2
@export var sub_type_time : float = 0.5

@export_group("Slam")
@export_range(0.0, 1.0) var slam_flash_alpha : float = 0.15
@export var slam_flash_fade : float = 0.3
@export var slam_shake_time : float = 0.35
@export var shake_strength : float = 4.0

@export_group("Cards")
@export var card_reveal_time : float = 0.6
@export var card_stagger : float = 0.25

@export_group("Choice")
@export var choice_color : Color = Color(0.3, 1.0, 0.5)
@export var reject_color : Color = Color(1.0, 0.25, 0.2)
@export var card_dissolve_time : float = 0.5
@export var chosen_delay : float = 0.2
@export var close_sub_time : float = 0.25

var _chosen : bool = false
var _tween : Tween
var _slam_tween : Tween
var _calm : bool = false
var _shake : float = 0.0

func _ready() -> void:
	hide()

func open() -> void:
	_chosen = false
	_kill_tweens()
	for child in node_card_container.get_children():
		node_card_container.remove_child(child)
		child.queue_free()

	if card_scene == null:
		push_error("UpgradeScreen: card_scene is not assigned")
		return

	var options := DataCollector.roll_upgrades(card_count)
	if options.is_empty():
		if DataCollector.upgrade_pool.is_empty():
			push_error("UpgradeScreen: upgrade pool is empty, check UPGRADE_DIR")
			return
		DataCollector.start_next_run()
		return

	var cards : Array[UpgradeCard] = []
	for upgrade in options:
		var card := card_scene.instantiate() as UpgradeCard
		node_card_container.add_child(card)
		card.set_data(upgrade)
		card.picked.connect(_on_picked)
		card.reveal = 0.0
		card.lock()
		cards.append(card)

	_calm = Settings.photosensitive()
	_shake = shake_strength * Settings.shake_scale()

	node_overlay.tint = vignette_tint
	node_overlay.intensity = 0.0
	node_flash.color = Color(1, 1, 1, 0)
	node_panel.scale = Vector2.ZERO
	node_title.modulate.a = 0.0
	node_title.scale = Vector2.ONE * (calm_title_start_scale if _calm else title_start_scale)
	node_sub.visible_ratio = 0.0
	show()

	await get_tree().process_frame
	node_title.pivot_offset = node_title.size / 2.0
	node_panel.pivot_offset = node_panel.size / 2.0

	_tween = create_tween()
	_tween.tween_property(node_overlay, "intensity", vignette_intensity, vignette_fade_time)
	_tween.parallel().tween_property(node_panel, "scale", Vector2.ONE, window_open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_slam)
	_tween.tween_property(node_title, "modulate:a", 1.0, 0.05)
	_tween.parallel().tween_property(node_title, "scale", Vector2.ONE, title_slam_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(node_sub, "visible_ratio", 1.0, sub_type_time)
	for i in cards.size():
		if i == 0:
			_tween.tween_property(cards[i], "reveal", 1.0, card_reveal_time)
		else:
			_tween.parallel().tween_property(cards[i], "reveal", 1.0, card_reveal_time).set_delay(i * card_stagger)
	_tween.tween_callback(_unlock_cards)

func _slam() -> void:
	if _calm:
		return
	node_flash.color = Color(1, 1, 1, slam_flash_alpha)
	_slam_tween = create_tween().set_parallel(true)
	_slam_tween.tween_property(node_flash, "color:a", 0.0, slam_flash_fade)
	_slam_tween.tween_method(_do_shake, 1.0, 0.0, slam_shake_time)

func _do_shake(s : float) -> void:
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * s

func _unlock_cards() -> void:
	for card in node_card_container.get_children():
		(card as UpgradeCard).unlock()

func _on_picked(upgrade : Upgrade) -> void:
	if _chosen:
		return
	_chosen = true
	DataCollector.apply_upgrade(upgrade)
	_kill_tweens()
	position = Vector2.ZERO

	_tween = create_tween().set_parallel(true)
	for node in node_card_container.get_children():
		var card := node as UpgradeCard
		card.lock()
		var is_pick := card.upgrade == upgrade
		card.tint_color = choice_color if is_pick else reject_color
		var delay := chosen_delay if is_pick else 0.0
		_tween.tween_property(card, "tint_mix", 1.0, 0.15).set_delay(delay)
		_tween.tween_property(card, "reveal", 0.0, card_dissolve_time).set_delay(delay)

	var title_scale := calm_title_start_scale if _calm else title_start_scale
	_tween.chain().tween_property(node_sub, "visible_ratio", 0.0, close_sub_time)
	_tween.chain().tween_property(node_title, "scale", Vector2.ONE * title_scale, title_slam_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(node_title, "modulate:a", 0.0, 0.05).set_delay(title_slam_time - 0.05)
	_tween.chain().tween_property(node_panel, "scale", Vector2.ZERO, window_open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(node_overlay, "intensity", 0.0, vignette_fade_time)
	_tween.chain().tween_callback(_close_done)

func _close_done() -> void:
	hide()
	DataCollector.start_next_run()

func _kill_tweens() -> void:
	if _tween: _tween.kill()
	if _slam_tween: _slam_tween.kill()