extends Node

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

var score : float = 0.0
var player : Player
var game_mode : GameMode = GameMode.TIMER_AND_FUEL
var fuel_end_delay : float = 0.5

var spawn_budget_usec : int = 2000 # max time all spawners may use per frame (2 ms)
var is_world_ready : bool = false
var _pending_jobs : int = 0
var _spawn_total : int = 0
var _spawn_done : int = 0
var _budget_frame : int = -1
var _budget_start_usec : int = 0

var end_reason : EndReason = EndReason.TIME_UP

func _ready() -> void:
	global_timer = Timer.new()
	global_timer.one_shot = true
	global_timer.timeout.connect(_on_timer_timeout)
	add_child(global_timer)
	_load_upgrades()
	SignalBus.fuel_depleted.connect(_on_fuel_depleted)

func _process(_delta : float) -> void:
	if is_running and uses_timer():
		SignalBus.emit_signal("time_updated", global_timer.time_left)

func _load_upgrades() -> void:
	upgrade_pool.clear()
	_scan_dir(UPGRADE_DIR)
	if upgrade_pool.is_empty():
		push_error("DataCollector: no Upgrade .tres files found under %s" % UPGRADE_DIR)
	else:
		print("DataCollector: loaded %d upgrades" % upgrade_pool.size())

func _scan_dir(path : String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("DataCollector: can't open %s" % path)
		return
	for sub in dir.get_directories():
		_scan_dir(path.path_join(sub))
	for file in dir.get_files():
		# Exported builds list resources as .remap
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var upgrade := load(path.path_join(clean)) as Upgrade
			if upgrade != null:
				upgrade_pool.append(upgrade)

func get_stat(stat : Upgrade.Stat, base : float) -> float:
	return (base + add_bonus.get(stat, 0.0)) * mult_bonus.get(stat, 1.0)

func get_stacks(upgrade : Upgrade) -> int:
	return stacks.get(upgrade, 0)

func apply_upgrade(upgrade : Upgrade) -> void:
	stacks[upgrade] = get_stacks(upgrade) + 1
	upgrades_taken += 1
	if upgrade.effects.is_empty():
		change_stat(upgrade.stat, upgrade.mode, upgrade.amount)
		return
	for e in upgrade.effects:
		effects.append(e)
		e.on_take(get_stacks(upgrade))

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
	var available := upgrade_pool.filter(func(u : Upgrade):
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

func get_quota() -> int:
	return roundi(base_quota * pow(quota_growth, maxi(run_number, 1) - 1) * get_stat(Upgrade.Stat.QUOTA, 1.0))

func get_chaos_scale() -> float:
	return 1.0 + 0.15 * (maxi(run_number, 1) - 1)

func run_start_hooks(player : Player) -> void:
	for e in effects:
		e.on_run_start(player)

func physics_hooks(player : Player, delta : float) -> void:
	for e in effects:
		e.on_physics(player, delta)

func start_next_run() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	var main := get_tree().current_scene as Main
	if main == null:
		get_tree().reload_current_scene() # fallback
		return
	main.respawn_debris()

func start_run(spawn_jobs : int = 0) -> void:
	run_number += 1
	time_limit = get_stat(Upgrade.Stat.TIME_LIMIT, base_time_limit)
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

func add_spawn_total(count : int) -> void:
	_spawn_total += count

func report_spawned() -> void:
	_spawn_done += 1
	if _spawn_total > 0:
		world_load_progress.emit(float(_spawn_done) / _spawn_total)

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

func register_delivery(debris : Debris) -> void:
	if not is_running:
		return

	var points : float = debris.stat_value * TAG_MULTIPLIERS.get(debris.tag, 1.0) * get_stat(Upgrade.Stat.SCORE, 1.0) * get_stat(Upgrade.Stat.DEBRIS_VALUE, 1.0)
	for e in effects:
		points = e.on_delivery(debris, points)
	score += points
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
	SignalBus.emit_signal("score_updated", roundi(score))

	_check_quota.call_deferred()

func _check_quota() -> void:
	if is_running and score >= get_quota():
		_finish_run(EndReason.QUOTA_MET)

func _on_timer_timeout() -> void:
	if is_running:
		_finish_run(EndReason.TIME_UP)

func _on_fuel_depleted() -> void:
	if not is_running or not uses_fuel():
		return
	is_running = false
	global_timer.stop()
	if is_instance_valid(player) and player.fx != null:
		await player.fx.sputter_finished
	await get_tree().create_timer(fuel_end_delay).timeout
	_finish_run(EndReason.FUEL_EMPTY)

func destroy_run() -> void:
	if is_running:
		_finish_run(EndReason.MELTDOWN)

func _finish_run(reason : EndReason) -> void:
	end_reason = reason
	is_running = false
	global_timer.stop()
	var final_score := roundi(score)
	if uses_timer():
		SignalBus.emit_signal("time_updated", 0.0)
	get_tree().paused = true
	SignalBus.emit_signal("run_finished", final_score, collected_by_tag.duplicate(true),
		reason != EndReason.MELTDOWN and final_score >= get_quota())

func uses_timer() -> bool:
	return game_mode == GameMode.TIMER_AND_FUEL or game_mode == GameMode.TIMER_ONLY

func uses_fuel() -> bool:
	return game_mode == GameMode.TIMER_AND_FUEL or game_mode == GameMode.FUEL_ONLY

func flag(name : StringName) -> int:
	return flags.get(name, 0)

func change_stat(stat : Upgrade.Stat, mode : Upgrade.Mode, amount : float) -> void:
	match mode:
		Upgrade.Mode.ADD:
			add_bonus[stat] = add_bonus.get(stat, 0.0) + amount
		Upgrade.Mode.MULTIPLY:
			mult_bonus[stat] = mult_bonus.get(stat, 1.0) * (1.0 + amount)
