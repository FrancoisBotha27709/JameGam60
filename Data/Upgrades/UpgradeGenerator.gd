@tool
extends EditorScript

const CATALOG_PATH := "res://Data/Upgrades/upgrade_catalog.json"
const OUTPUT_DIR := "res://Data/Upgrades/Resources/"

func _run() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Upgrade generator: cannot open catalogue: " + CATALOG_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not (parsed is Dictionary) or not (parsed.get("upgrades", null) is Array):
		push_error("Upgrade generator: catalogue JSON must contain an 'upgrades' array.")
		return

	var make_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if make_dir_error != OK:
		push_error("Upgrade generator: cannot create output directory. Error: %s" % make_dir_error)
		return

	var written := 0
	var failed := 0
	var ids := {}

	for entry_variant in parsed["upgrades"]:
		if not (entry_variant is Dictionary):
			push_warning("Upgrade generator: skipped non-object catalogue entry.")
			failed += 1
			continue

		var entry: Dictionary = entry_variant
		var id := str(entry.get("id", "")).strip_edges()
		var title := str(entry.get("title", "")).strip_edges()

		if id.is_empty() or title.is_empty():
			push_warning("Upgrade generator: entry missing id or title.")
			failed += 1
			continue
		if ids.has(id):
			push_warning("Upgrade generator: duplicate id skipped: " + id)
			failed += 1
			continue
		ids[id] = true

		var upgrade := Upgrade.new()
		upgrade.resource_name = title
		upgrade.title = title
		upgrade.description = str(entry.get("description", ""))
		upgrade.max_stacks = maxi(1, int(entry.get("max_stacks", 3)))
		upgrade.effects.clear()

		var effect_data: Variant = entry.get("effects", [])
		if not (effect_data is Array) or effect_data.is_empty():
			push_warning("Upgrade generator: '%s' has no effects; skipped." % title)
			failed += 1
			continue

		var valid_entry := true
		for effect_variant in effect_data:
			if not (effect_variant is Dictionary):
				valid_entry = false
				break
			var effect := _build_effect(effect_variant)
			if effect == null:
				push_warning("Upgrade generator: invalid effect in '%s'; skipped." % title)
				valid_entry = false
				break
			upgrade.effects.append(effect)

		if not valid_entry:
			failed += 1
			continue

		# Keep each generated resource independent; effects are embedded subresources.
		var safe_name := id.validate_filename()
		var output_path := OUTPUT_DIR.path_join(safe_name + ".tres")
		var save_error := ResourceSaver.save(upgrade, output_path)
		if save_error != OK:
			push_error("Upgrade generator: failed saving %s (error %s)." % [output_path, save_error])
			failed += 1
		else:
			written += 1

	print("Upgrade generator finished: %d written, %d skipped/failed. Output: %s" % [
		written, failed, OUTPUT_DIR
	])
	get_editor_interface().get_resource_filesystem().scan()

func _build_effect(data: Dictionary) -> UpgradeEffect:
	var kind := str(data.get("type", ""))

	match kind:
		"StatEffect":
			var effect := StatEffect.new()
			effect.stats.clear()
			var stat_names: Variant = data.get("stats", [])
			if not (stat_names is Array) or stat_names.is_empty():
				return null
			for stat_name_variant in stat_names:
				var stat_name := str(stat_name_variant)
				if not Upgrade.Stat.has(stat_name):
					push_warning("Unknown Upgrade.Stat name: " + stat_name)
					return null
				effect.stats.append(int(Upgrade.Stat[stat_name]))
			var mode_name := str(data.get("mode", "MULTIPLY"))
			if not Upgrade.Mode.has(mode_name):
				return null
			effect.mode = int(Upgrade.Mode[mode_name])
			effect.amount = float(data.get("amount", 0.1))
			return effect

		"TickEffect":
			var effect := TickEffect.new()
			effect.fuel_per_sec = float(data.get("fuel_per_sec", 0.0))
			effect.heat_per_sec = float(data.get("heat_per_sec", 0.0))
			effect.spin = float(data.get("spin", 0.0))
			return effect

		"RandomStatEffect":
			var effect := RandomStatEffect.new()
			effect.pool.clear()
			var stat_names: Variant = data.get("pool", [])
			if stat_names is Array:
				for stat_name_variant in stat_names:
					var stat_name := str(stat_name_variant)
					if not Upgrade.Stat.has(stat_name):
						push_warning("Unknown Upgrade.Stat name in random pool: " + stat_name)
						return null
					effect.pool.append(int(Upgrade.Stat[stat_name]))
			effect.count = maxi(1, int(data.get("count", 3)))
			effect.min_amount = float(data.get("min_amount", -0.3))
			effect.max_amount = float(data.get("max_amount", 0.3))
			if effect.min_amount > effect.max_amount:
				return null
			return effect

		"RandomKickEffect":
			var effect := RandomKickEffect.new()
			effect.strength = maxf(0.0, float(data.get("strength", 40.0)))
			return effect

		"FlagEffect":
			var effect := FlagEffect.new()
			effect.flag = StringName(str(data.get("flag", "unknown_flag")))
			return effect

		_:
			push_warning("Unsupported effect type: " + kind)
			return null
