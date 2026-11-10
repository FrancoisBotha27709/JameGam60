
extends Node
# DataCollector
signal world_load_progress(fraction : float)
signal world_ready

enum EndReason { QUOTA_MET, TIME_UP, FUEL_EMPTY, MELTDOWN }

const TAG_MULTIPLIERS := {
	Debris.Tag.NULL: 1.0,
	Debris.Tag.PLASTIC: 1.0,
	Debris.Tag.METAL: 1.5,
	Debris.Tag.CEMENT: 2.0,
}

enum GameMode {
	TIMER_AND_FUEL,
	TIMER_ONLY,
	FUEL_ONLY,
	FREE_PLAY
}

const UPGRADE_DIR := "res://Data/Upgrades/"
const SHIP_DIR := "res://Assets/UI/Ship/Designs/"

var base_quota : int = 5
var quota_growth : float = 1.5

var upgrade_pool : Array[Upgrade] = []
var flags : Dictionary = {}
var effects : Array[UpgradeEffect] = []

var stacks : Dictionary = {}
var add_bonus : Dictionary = {}
var mult_bonus : Dictionary = {}
var collected_by_tag : Dictionary = {}

var is_running : bool = false
var global_timer : Timer
var time_limit : float = 180.0
var base_time_limit : float = 180.0
var run_number : int = 0
var upgrades_taken : int = 0
var items_collected : int = 0

# Current run score. Resets whenever a new run starts.
var score : float = 0.0

# Persistent progress towards the next quota.
# Excess points are carried between quota completions.
var quota_progress : float = 0.0

var player : Player
var game_mode : GameMode = GameMode.TIMER_AND_FUEL
var fuel_end_delay : float = 0.5

var spawn_budget_usec : int = 2000
var is_world_ready : bool = false
var _pending_jobs : int = 0
var _spawn_total : int = 0
var _spawn_done : int = 0
var _budget_frame : int = -1
var _budget_start_usec : int = 0

var end_reason : EndReason = EndReason.TIME_UP

# Ships
var ship_designs : Array[ShipDesign] = []
var selected_ship_index : int = 0
var ship_effects : Array[UpgradeEffect] = []
var _ship_abilities : Array[Upgrade] = []
var _ship_applied : bool = false


func _ready() -> void:
	global_timer = Timer.new()
	global_timer.one_shot = true
	global_timer.timeout.connect(_on_timer_timeout)
	add_child(global_timer)

	_load_upgrades()
	_load_ship_designs()

	SignalBus.fuel_depleted.connect(_on_fuel_depleted)


func _process(_delta : float) -> void:
	if is_running and uses_timer():
		SignalBus.emit_signal("time_updated", global_timer.time_left)


#endregion
#region Loading


func _load_upgrades() -> void:
	upgrade_pool.clear()
	_scan_dir(UPGRADE_DIR)


func _load_ship_designs() -> void:
	ship_designs.clear()
	_scan_ship_dir(SHIP_DIR)
	ship_designs.sort_custom(
		func(a : ShipDesign, b : ShipDesign):
			return a.ship_name < b.ship_name
	)


func _scan_dir(path : String) -> void:
	var dir := DirAccess.open(path)

	if dir == null:
		push_warning("Could not open upgrade directory: " + path)
		return

	for sub in dir.get_directories():
		_scan_dir(path.path_join(sub))

	for file in dir.get_files():
		var clean := file.trim_suffix(".remap")

		if not clean.ends_with(".tres"):
			continue

		var resource_path := path.path_join(clean)
		var resource := load(resource_path)

		if resource == null:
			push_error("Failed to load upgrade resource: " + resource_path)
			continue

		var upgrade := resource as Upgrade

		if upgrade == null:
			push_warning("Resource is not an Upgrade: " + resource_path)
			continue

		upgrade_pool.append(upgrade)


func _scan_ship_dir(path : String) -> void:
	var dir := DirAccess.open(path)

	if dir == null:
		push_warning("Could not open ship design directory: " + path)
		return

	for sub in dir.get_directories():
		_scan_ship_dir(path.path_join(sub))

	for file in dir.get_files():
		var clean := file.trim_suffix(".remap")

		if not clean.ends_with(".tres"):
			continue

		var resource_path := path.path_join(clean)
		var resource := load(resource_path)

		if resource == null:
			push_error("Failed to load ship design: " + resource_path)
			continue

		var design := resource as ShipDesign

		if design == null:
			push_warning("Resource is not a ShipDesign: " + resource_path)
			continue

		ship_designs.append(design)


#endregion
#region Ships


func get_selected_ship() -> ShipDesign:
	if ship_designs.is_empty():
		return null

	return ship_designs[
		clampi(selected_ship_index, 0, ship_designs.size() - 1)
	]


## Registers the selected ship's abilities.
## Effects are duplicated so runtime state never modifies source resources.
func set_ship_abilities(abilities : Array[Upgrade]) -> void:
	if _ship_applied and abilities == _ship_abilities:
		return

	_ship_abilities = abilities
	_apply_ship_abilities()


func _apply_ship_abilities() -> void:
	ship_effects.clear()

	for ability in _ship_abilities:
		if not is_instance_valid(ability):
			continue

		if ability.effects.is_empty():
			change_stat(ability.stat, ability.mode, ability.amount)
			continue

		for effect in ability.effects:
			if not is_instance_valid(effect):
				continue

			var copy := effect.duplicate(true) as UpgradeEffect

			if copy == null:
				continue

			ship_effects.append(copy)
			copy.on_take(1)

	_ship_applied = true


#endregion
#region Stats and upgrades


func get_stat(stat : Upgrade.Stat, base : float) -> float:
	return (base + add_bonus.get(stat, 0.0)) * mult_bonus.get(stat, 1.0)


func get_stacks(upgrade : Upgrade) -> int:
	return stacks.get(upgrade, 0)


func apply_upgrade(upgrade : Upgrade) -> void:
	if not is_instance_valid(upgrade):
		return

	var current_stacks := get_stacks(upgrade) + 1

	stacks[upgrade] = current_stacks
	upgrades_taken += 1

	if upgrade.effects.is_empty():
		change_stat(upgrade.stat, upgrade.mode, upgrade.amount)
		return

	for effect in upgrade.effects:
		if not is_instance_valid(effect):
			continue

		var copy := effect.duplicate(true) as UpgradeEffect

		if copy == null:
			continue

		effects.append(copy)
		copy.on_take(current_stacks)


func is_stat_relevant(stat : Upgrade.Stat) -> bool:
	match stat:
		Upgrade.Stat.TIME_LIMIT:
			return uses_timer()

		Upgrade.Stat.FUEL_MAX, Upgrade.Stat.FUEL_BURN, Upgrade.Stat.WEIGHT_FUEL, Upgrade.Stat.BOOST_FUEL:
			return uses_fuel()

		Upgrade.Stat.HEAT_MAX, Upgrade.Stat.HEAT_GAIN, Upgrade.Stat.COOL_RATE, Upgrade.Stat.MELTDOWN_TIME:
			return game_mode != GameMode.FREE_PLAY

	return true


func roll_upgrades(count : int) -> Array[Upgrade]:
	var available := upgrade_pool.filter(
		func(u : Upgrade):
			return get_stacks(u) < u.max_stacks and u.is_relevant()
	)

	available.shuffle()

	var result : Array[Upgrade] = []
	result.assign(available.slice(0, count))

	return result


func reset_progress() -> void:
	stacks.clear()
	add_bonus.clear()
	mult_bonus.clear()
	flags.clear()
	effects.clear()

	run_number = 0
	upgrades_taken = 0
	score = 0.0
	quota_progress = 0.0
	items_collected = 0
	collected_by_tag.clear()

	_apply_ship_abilities()


func change_stat(stat : Upgrade.Stat, mode : Upgrade.Mode, amount : float) -> void:
	match mode:
		Upgrade.Mode.ADD:
			add_bonus[stat] = add_bonus.get(stat, 0.0) + amount

		Upgrade.Mode.MULTIPLY:
			mult_bonus[stat] = mult_bonus.get(stat, 1.0) * (1.0 + amount)


func flag(name : StringName) -> int:
	return flags.get(name, 0)


func get_quota() -> int:
	return roundi(
		base_quota
		* pow(quota_growth, maxi(run_number, 1) - 1)
		* get_stat(Upgrade.Stat.QUOTA, 1.0)
	)


## Returns current progress towards the active quota.
func get_quota_progress() -> float:
	return quota_progress


## Returns progress as a percentage between 0 and 1.
func get_quota_percentage() -> float:
	var quota := get_quota()

	if quota <= 0:
		return 0.0

	return clampf(quota_progress / float(quota), 0.0, 1.0)


func get_chaos_scale() -> float:
	return 1.0 + 0.15 * (maxi(run_number, 1) - 1)


#endregion
#region Effect hooks


# Ship abilities run first, then upgrade effects.

func run_start_hooks(player : Player) -> void:
	for e in ship_effects:
		e.on_run_start(player)

	for e in effects:
		e.on_run_start(player)


func physics_hooks(player : Player, delta : float) -> void:
	for e in ship_effects:
		e.on_physics(player, delta)

	for e in effects:
		e.on_physics(player, delta)


#endregion
#region Run flow


func start_next_run() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0

	var main := get_tree().current_scene as Main

	if main == null:
		get_tree().reload_current_scene()
		return

	main.respawn_debris()


func start_run(spawn_jobs : int = 0) -> void:
	run_number += 1

	time_limit = get_stat(
		Upgrade.Stat.TIME_LIMIT,
		base_time_limit
	)

	# The run score always starts at zero.
	# Quota progress is preserved separately.
	score = 0.0

	items_collected = 0
	collected_by_tag.clear()

	global_timer.stop()

	is_running = false
	is_world_ready = false

	_pending_jobs = spawn_jobs
	_spawn_total = 0
	_spawn_done = 0

	SignalBus.emit_signal("run_started", time_limit)
	SignalBus.emit_signal("time_updated", time_limit)
	SignalBus.emit_signal("score_updated", 0)

	# Refresh depot visuals using persistent quota progress.
	for depot in get_tree().get_nodes_in_group("Depot"):
		if depot is Depot:
			depot.update_depot_sprite()

	if spawn_jobs <= 0:
		_begin_clock()


func _begin_clock() -> void:
	if uses_timer():
		global_timer.start(time_limit)
	else:
		global_timer.stop()

	is_running = true
	is_world_ready = true

	world_ready.emit()

	# Important:
	# If carried progress already satisfies the next quota,
	# complete it immediately and award another upgrade.
	_check_quota.call_deferred()


func add_spawn_total(count : int) -> void:
	_spawn_total += count


func report_spawned() -> void:
	_spawn_done += 1

	if _spawn_total > 0:
		world_load_progress.emit(
			float(_spawn_done) / _spawn_total
		)


func finish_spawn_job() -> void:
	_pending_jobs -= 1

	if _pending_jobs <= 0 and not is_world_ready:
		_begin_clock()


func spawn_checkpoint() -> void:
	var frame := Engine.get_process_frames()

	if frame != _budget_frame:
		_budget_frame = frame
		_budget_start_usec = Time.get_ticks_usec()
		return

	if Time.get_ticks_usec() - _budget_start_usec >= spawn_budget_usec:
		await get_tree().process_frame


#endregion
#region Delivery and quota


func register_delivery(debris : Debris, value : int = -1) -> void:
	if not is_running:
		return

	# value comes from DebrisObject.get_value(), which includes the quantum multiplier.
	var base_value : int = value if value >= 0 else debris.stat_value

	var points : float = (
		base_value
		* TAG_MULTIPLIERS.get(debris.tag, 1.0)
		* get_stat(Upgrade.Stat.SCORE, 1.0)
		* get_stat(Upgrade.Stat.DEBRIS_VALUE, 1.0)
	)

	for e in ship_effects:
		points = e.on_delivery(debris, points)

	for e in effects:
		points = e.on_delivery(debris, points)

	# Current run score.
	score += points

	# Persistent quota progress.
	quota_progress += points

	items_collected += 1

	var tag_name : String = Debris.Tag.keys()[debris.tag]

	var entry : Dictionary = collected_by_tag.get(tag_name, {
		"count": 0,
		"points": 0.0,
		"debris": debris,
	})

	entry["count"] += 1
	entry["points"] += points

	collected_by_tag[tag_name] = entry

	for depot in get_tree().get_nodes_in_group("Depot"):
		if depot is Depot:
			depot.update_depot_sprite()

	SignalBus.emit_signal("score_updated", roundi(score))

	_check_quota.call_deferred()


func _check_quota() -> void:
	if not is_running:
		return

	var quota := get_quota()

	if quota <= 0:
		return

	if quota_progress < quota:
		return

	# Remove only the completed quota.
	# Everything left over carries into the next quota.
	quota_progress -= float(quota)

	# This run is now officially a quota completion.
	_finish_run(EndReason.QUOTA_MET)


#endregion
#region Run ending


func _on_timer_timeout() -> void:
	if is_running:
		_finish_run(EndReason.TIME_UP)

func _on_fuel_depleted() -> void:
	if not is_running or not uses_fuel():
		return

	var this_run := run_number

	is_running = false  # stop deliveries/quota while sputtering
	global_timer.stop()

	if is_instance_valid(player):
		for effect : ShipFX in player.fx:
			if is_instance_valid(effect) and effect.has_signal("sputter_finished"):
				await effect.sputter_finished
				break

	await get_tree().create_timer(fuel_end_delay).timeout

	# A new run started while we were waiting, so don't end it.
	if run_number != this_run:
		return

	_finish_run(EndReason.FUEL_EMPTY, true)

func destroy_run() -> void:
	if is_running:
		_finish_run(EndReason.MELTDOWN)

func _finish_run(reason : EndReason, force : bool = false) -> void:
	if not is_running and not force:
		return

	end_reason = reason
	is_running = false

	global_timer.stop()

	var final_score := roundi(score)

	if uses_timer():
		SignalBus.emit_signal("time_updated", 0.0)

	# Only an actual quota completion resets the depot.
	if reason == EndReason.QUOTA_MET:
		for depot in get_tree().get_nodes_in_group("Depot"):
			if depot is Depot:
				depot.reset_depot()

	get_tree().paused = true

	# Success is determined by the actual end reason,
	# NOT by comparing the current run score against the quota.
	SignalBus.emit_signal(
		"run_finished",
		final_score,
		collected_by_tag.duplicate(true),
		reason == EndReason.QUOTA_MET
	)

#endregion
#region Game modes


func uses_timer() -> bool:
	return (
		game_mode == GameMode.TIMER_AND_FUEL
		or game_mode == GameMode.TIMER_ONLY
	)


func uses_fuel() -> bool:
	return (
		game_mode == GameMode.TIMER_AND_FUEL
		or game_mode == GameMode.FUEL_ONLY
	)


#endregion
