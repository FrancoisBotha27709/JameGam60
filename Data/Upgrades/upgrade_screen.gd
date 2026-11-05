extends Control
class_name UpgradeScreen

@export_group("Nodes", "node_")
@export var node_card_container : HBoxContainer
@export var node_overlay : DitherVignette
@export var node_panel : Control
@export var node_title : Label
@export var node_sub : RichTextLabel
@export var node_flash : ColorRect

@export var card_scene : PackedScene
@export_range(1, 10) var card_count : int = 3

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
var _session_id : int = 0

func _ready() -> void:
	hide()
	position = Vector2.ZERO

func _muffle_music() -> void:
	var player := DataCollector.player as Player
	if is_instance_valid(player):
		player.muffle_music()

func _restore_music() -> void:
	var player := DataCollector.player as Player
	if is_instance_valid(player):
		player.restore_music()

func open() -> void:
	if not _nodes_valid():
		return

	_session_id += 1
	var session_id := _session_id

	_chosen = false
	_kill_tweens()

	position = Vector2.ZERO
	_clear_cards()

	if card_scene == null:
		push_error("UpgradeScreen: card_scene has not been assigned.")
		return

	var options := DataCollector.roll_upgrades(card_count)

	if options.is_empty():
		if DataCollector.upgrade_pool.is_empty():
			return

		DataCollector.start_next_run()
		return

	var cards : Array[UpgradeCard] = []

	for upgrade in options:
		if upgrade == null:
			continue

		var instance := card_scene.instantiate()
		var card := instance as UpgradeCard

		if card == null:
			instance.queue_free()
			push_error("UpgradeScreen: card_scene must contain an UpgradeCard.")
			continue

		node_card_container.add_child(card)
		card.set_data(upgrade)
		card.picked.connect(_on_picked)
		card.reveal = 0.0
		card.lock()
		cards.append(card)

	if cards.is_empty():
		push_error("UpgradeScreen: no valid upgrade cards could be created.")
		return

	_calm = Settings.photosensitive()
	_shake = shake_strength * Settings.shake_scale()

	node_overlay.tint = vignette_tint
	node_overlay.intensity = 0.0
	node_flash.color = Color(1.0, 1.0, 1.0, 0.0)

	node_panel.scale = Vector2.ZERO
	node_title.modulate.a = 0.0
	node_title.scale = Vector2.ONE * (
		calm_title_start_scale if _calm else title_start_scale
	)
	node_sub.visible_ratio = 0.0

	_muffle_music()
	show()

	await get_tree().process_frame

	if not _session_is_current(session_id):
		return

	node_title.pivot_offset = node_title.size / 2.0
	node_panel.pivot_offset = node_panel.size / 2.0

	_play_intro(cards, session_id)

func _play_intro(cards : Array[UpgradeCard], session_id : int) -> void:
	_tween = create_tween()

	_tween.tween_property(
		node_overlay,
		"intensity",
		vignette_intensity,
		vignette_fade_time
	)

	_tween.parallel().tween_property(
		node_panel,
		"scale",
		Vector2.ONE,
		window_open_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.tween_callback(_slam)

	_tween.tween_property(
		node_title,
		"modulate:a",
		1.0,
		0.05
	)

	_tween.parallel().tween_property(
		node_title,
		"scale",
		Vector2.ONE,
		title_slam_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		node_sub,
		"visible_ratio",
		1.0,
		sub_type_time
	)

	await _tween.finished

	if not _session_is_current(session_id):
		return

	_reveal_cards(cards, session_id)

func _reveal_cards(cards : Array[UpgradeCard], session_id : int) -> void:
	var reveal_tween := create_tween().set_parallel(true)
	_tween = reveal_tween

	for i in range(cards.size()):
		var card := cards[i]

		if not is_instance_valid(card):
			continue

		reveal_tween.tween_property(
			card,
			"reveal",
			1.0,
			card_reveal_time
		).set_delay(i * card_stagger)

	await reveal_tween.finished

	if not _session_is_current(session_id):
		return

	_unlock_cards()

func _slam() -> void:
	if _calm or not is_instance_valid(node_flash):
		return

	node_flash.color = Color(1.0, 1.0, 1.0, slam_flash_alpha)

	_slam_tween = create_tween().set_parallel(true)

	_slam_tween.tween_property(
		node_flash,
		"color:a",
		0.0,
		slam_flash_fade
	)

	_slam_tween.tween_method(
		_do_shake,
		1.0,
		0.0,
		slam_shake_time
	)

func _do_shake(amount : float) -> void:
	if _calm:
		position = Vector2.ZERO
		return

	position = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * _shake * amount

func _unlock_cards() -> void:
	if not is_instance_valid(node_card_container):
		return

	for child in node_card_container.get_children():
		var card := child as UpgradeCard

		if is_instance_valid(card):
			card.unlock()

func _on_picked(upgrade : Upgrade) -> void:
	if _chosen or upgrade == null:
		return

	_chosen = true
	_session_id += 1
	var session_id := _session_id

	_kill_tweens()
	position = Vector2.ZERO

	DataCollector.apply_upgrade(upgrade)
	_restore_music()

	var close_tween := create_tween().set_parallel(true)
	_tween = close_tween

	for child in node_card_container.get_children():
		var card := child as UpgradeCard

		if not is_instance_valid(card):
			continue

		card.lock()

		var is_pick := card.upgrade == upgrade
		card.tint_color = choice_color if is_pick else reject_color

		var delay := chosen_delay if is_pick else 0.0

		close_tween.tween_property(
			card,
			"tint_mix",
			1.0,
			0.15
		).set_delay(delay)

		close_tween.tween_property(
			card,
			"reveal",
			0.0,
			card_dissolve_time
		).set_delay(delay)

	close_tween.chain().tween_interval(
		maxf(card_dissolve_time + chosen_delay, 0.0)
	)

	close_tween.tween_property(
		node_sub,
		"visible_ratio",
		0.0,
		close_sub_time
	)

	close_tween.parallel().tween_property(
		node_title,
		"scale",
		Vector2.ONE * (
			calm_title_start_scale if _calm else title_start_scale
		),
		title_slam_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	close_tween.parallel().tween_property(
		node_title,
		"modulate:a",
		0.0,
		0.05
	)

	close_tween.chain().tween_property(
		node_panel,
		"scale",
		Vector2.ZERO,
		window_open_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	close_tween.parallel().tween_property(
		node_overlay,
		"intensity",
		0.0,
		vignette_fade_time
	)

	close_tween.chain().tween_callback(_close_done.bind(session_id))

func _close_done(session_id : int) -> void:
	if not is_inside_tree() or session_id != _session_id:
		return

	hide()
	position = Vector2.ZERO
	DataCollector.start_next_run()

func _clear_cards() -> void:
	if not is_instance_valid(node_card_container):
		return

	for child in node_card_container.get_children():
		node_card_container.remove_child(child)
		child.queue_free()

func _kill_tweens() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if _slam_tween != null and _slam_tween.is_valid():
		_slam_tween.kill()

	_tween = null
	_slam_tween = null

func _session_is_current(session_id : int) -> bool:
	return (
		is_inside_tree()
		and session_id == _session_id
		and not _chosen
	)

func _nodes_valid() -> bool:
	if (
		node_card_container == null
		or node_overlay == null
		or node_panel == null
		or node_title == null
		or node_sub == null
		or node_flash == null
	):
		push_error("UpgradeScreen: one or more exported node references are missing.")
		return false

	return true