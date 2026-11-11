extends Control
class_name RunEndBanner

signal sequence_finished

const PAYLOAD : String = "[color=#ff5966][ ERROR ] [/color] Memory buffer overflow
[color=#ff5966][ ERROR ] [/color] Stack corruption detected
[color=#ff8c33][ WARN ] [/color] CPU temp critical: 98C
[color=#ff5966][ ERROR ] [/color] Page fault in kernel space
[color=#ff5966][ ERROR ] [/color] Heap allocation failed
[color=#ff8c33][ WARN ] [/color] Fan speed 0 RPM
[color=#ff5966][ ERROR ] [/color] Segmentation fault
[color=#ff5966][ ERROR ] [/color] Disk I/O timeout
[color=#ff5966][ ERROR ] [/color] Filesystem journal corrupted
[color=#ff8c33][ WARN ] [/color] Swap space exhausted
[color=#ff5966][ ERROR ] [/color] Process 1337 unresponsive
[color=#ff5966][ ERROR ] [/color] Kernel panic: unable to sync
[color=#ff5966][ ERROR ] [/color] Watchdog timer expired
[color=#ff5966][ ERROR ] [/color] NULL pointer dereference
[color=#ff8c33][ WARN ] [/color] Voltage drop on 3.3V rail
[color=#ff5966][ ERROR ] [/color] Network stack failure
[color=#ff5966][ ERROR ] [/color] DNS resolver crashed
[color=#ff5966][ ERROR ] [/color] Packet checksum mismatch
[color=#ff5966][ ERROR ] [/color] Cache coherency violation
[color=#ff5966][ ERROR ] [/color] Interrupt storm on IRQ 7
[color=#ff8c33][ WARN ] [/color] Thermal throttle ignored
[color=#ff5966][ ERROR ] [/color] GPU driver hung
[color=#ff5966][ ERROR ] [/color] Framebuffer unmapped
[color=#ff5966][ ERROR ] [/color] Mutex deadlock detected
[color=#ff5966][ ERROR ] [/color] Race condition in scheduler
[color=#ff5966][ ERROR ] [/color] Bootloader signature invalid
[color=#ff5966][ ERROR ] [/color] RAID array degraded
[color=#ff5966][ ERROR ] [/color] Sector 0x00FF unreadable
[color=#ff5966][ ERROR ] [/color] Encryption keys lost
[color=#ff8c33][ WARN ] [/color] Backup power failing
[color=#ff5966][ ERROR ] [/color] Double fault exception
[color=#ff5966][ ERROR ] [/color] Recovery routine failed
[color=#ff5966][ ERROR ] [/color] Recovery routine failed
[color=#ff5966][ ERROR ] [/color] Recovery routine failed
[color=#ff5966][ ERROR ] [/color] Kernel module unload failed
[color=#ff5966][ ERROR ] [/color] Orphaned process tree
[color=#ff5966][ ERROR ] [/color] Zombie process overflow
[color=#ff8c33][ WARN ] [/color] File descriptors exhausted
[color=#ff5966][ ERROR ] [/color] Socket bind failed
[color=#ff5966][ ERROR ] [/color] Connection reset by peer
[color=#ff5966][ ERROR ] [/color] TLS handshake aborted
[color=#ff5966][ ERROR ] [/color] Certificate chain invalid
[color=#ff5966][ ERROR ] [/color] Authentication daemon dead
[color=#ff5966][ ERROR ] [/color] Privilege escalation blocked
[color=#ff8c33][ WARN ] [/color] Unauthorized memory access
[color=#ff5966][ ERROR ] [/color] Syscall table modified
[color=#ff5966][ ERROR ] [/color] Kernel integrity check failed
[color=#ff5966][ ERROR ] [/color] ACPI table corrupted
[color=#ff5966][ ERROR ] [/color] BIOS checksum error
[color=#ff5966][ ERROR ] [/color] CMOS battery dead
[color=#ff8c33][ WARN ] [/color] System clock drift: +4382s
[color=#ff5966][ ERROR ] [/color] Timer interrupt lost
[color=#ff5966][ ERROR ] [/color] Scheduler queue overflow
[color=#ff5966][ ERROR ] [/color] Context switch failed
[color=#ff5966][ ERROR ] [/color] Thread pool exhausted
[color=#ff5966][ ERROR ] [/color] Pipe broken
[color=#ff5966][ ERROR ] [/color] Buffer underrun
[color=#ff5966][ ERROR ] [/color] Buffer overrun
[color=#ff5966][ ERROR ] [/color] Unhandled exception 0xC0000005
[color=#ff5966][ ERROR ] [/color] Unhandled exception 0xC0000094
[color=#ff5966][ ERROR ] [/color] Unhandled exception 0xDEADBEEF
[color=#ff8c33][ WARN ] [/color] Disk SMART status: FAILING
[color=#ff5966][ ERROR ] [/color] Bad block count: 40960
[color=#ff5966][ ERROR ] [/color] Inode table destroyed
[color=#ff5966][ ERROR ] [/color] Superblock invalid
[color=#ff5966][ ERROR ] [/color] Mount failed: /home
[color=#ff5966][ ERROR ] [/color] Mount failed: /var
[color=#ff5966][ ERROR ] [/color] Mount failed: /boot
[color=#ff5966][ ERROR ] [/color] Mount failed: /
[color=#ff8c33][ WARN ] [/color] Read-only filesystem forced
[color=#ff5966][ ERROR ] [/color] Write failed: no space left
[color=#ff5966][ ERROR ] [/color] Log rotation failed
[color=#ff5966][ ERROR ] [/color] Audit subsystem offline
[color=#ff5966][ ERROR ] [/color] Firewall rules purged
[color=#ff5966][ ERROR ] [/color] Intrusion detection offline
[color=#ff8c33][ WARN ] [/color] Unknown device on PCI bus
[color=#ff5966][ ERROR ] [/color] PCI bus error
[color=#ff5966][ ERROR ] [/color] USB controller reset loop
[color=#ff5966][ ERROR ] [/color] Audio driver crashed
[color=#ff5966][ ERROR ] [/color] Input device lost
[color=#ff5966][ ERROR ] [/color] Display signal lost
[color=#ff5966][ ERROR ] [/color] VRAM corruption detected
[color=#ff5966][ ERROR ] [/color] Shader compile failed
[color=#ff5966][ ERROR ] [/color] Render pipeline stalled
[color=#ff8c33][ WARN ] [/color] GPU temp critical: 112C
[color=#ff5966][ ERROR ] [/color] Voltage regulator fault
[color=#ff5966][ ERROR ] [/color] Power rail 12V unstable
[color=#ff5966][ ERROR ] [/color] Power rail 5V unstable
[color=#ff5966][ ERROR ] [/color] Power rail 3.3V collapsed
[color=#ff8c33][ WARN ] [/color] Battery critical: 1%
[color=#ff5966][ ERROR ] [/color] Machine check exception
[color=#ff5966][ ERROR ] [/color] ECC uncorrectable error
[color=#ff5966][ ERROR ] [/color] ECC uncorrectable error
[color=#ff5966][ ERROR ] [/color] ECC uncorrectable error
[color=#ff5966][ ERROR ] [/color] DIMM 0 not responding
[color=#ff5966][ ERROR ] [/color] DIMM 1 not responding
[color=#ff5966][ ERROR ] [/color] DIMM 2 not responding
[color=#ff5966][ ERROR ] [/color] DIMM 3 not responding
[color=#ff5966][ ERROR ] [/color] Memory map destroyed
[color=#ff5966][ ERROR ] [/color] Triple fault imminent
[color=#ff5966][ ERROR ] [/color] Memory integrity c0rrupt3d
[color=#ff5966][ ERROR ] [/color] St4ck 0v3rfl0w
[color=#ff5966][ ERROR ] [/color] K3rn3l p4n1c
[color=#ff5966][ ERROR ] [/color] Ret_urn addr3ss ov3rwr1tt3n
[color=#ff5966][ ERROR ] [/color] ░▒▓█ SYSTEM UNSTABLE █▓▒░
[color=#ff5966][ ERROR ] [/color] ▓▒░ DATA LOSS IN PROGRESS ░▒▓
[color=#ff5966][ ERROR ] [/color] Cor3 t3mp3r4tur3 runaway
[color=#ff5966][ ERROR ] [/color] Thermal shutdown FAILED
[color=#ff5966][ ERROR ] [/color] Emergency halt FAILED
[color=#ff5966][ ERROR ] [/color] Emergency halt FAILED
[color=#ff5966][ ERROR ] [/color] Emergency halt FAILED
[color=#ff5966][ ERROR ] [/color] ERROR ERROR ERROR ERROR
[color=#ff5966][ ERROR ] [/color] ERROR ERROR ERROR ERROR
[color=#ff5966][ ERROR ] [/color] ERROR ERROR ERROR ERROR
[color=#ff5966][ ERROR ] [/color] 0x00000000 0x00000000 0x0000
[color=#ff5966][ ERROR ] [/color] ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
[color=#ff5966][ ERROR ] [/color] All processes terminated
[color=#ff5966][ ERROR ] [/color] All memory freed
[color=#ff5966][ ERROR ] [/color] All drives unmounted
[color=#ff5966][ ERROR ] [/color] Shutdown sequence failed
[color=#ff5966][ ERROR ] [/color] Power supply fail
"
const PAYLOAD_TAIL : String = "[color=#ff5966][ ERROR ] [/color] Power suppl
[color=#ff5966][ ERROR ] [/color] Pow
[color=#ff5966][ ERROR ] [/color] P
[color=#ff5966][ ERR"

@export_group("Nodes")
@export var overlay : DitherVignette
@export var backpanel : PanelContainer
@export var tag : Label
@export var title : Label
@export var sub : Label
@export var score : Label
@export var flash : ColorRect
@export var overlow : RichTextLabel
@export var summary_lbl : Label
@export var backdrop : HangarBackdrop
@export var progress_bar : HangarProgressBar

@export_group("Error Text")
@export_range(1, 10) var payload_repeats : int = 1
@export var shake_meltdown : float = 30.0
@export var shake_default : float = 14.0
@export var fade_in_time : float = 0.5
@export var death_fade : float = 0.3
@export var crash_time : float = 0.3

@export_group("Phase 1 : Death")
@export_subgroup("Intro")
@export var intro_time : float = 0.3
@export_range(0.0, 1.0) var intro_intensity : float = 0.2

@export_subgroup("Meltdown (accelerating spew)")
@export var spew_time : float = 1.8
@export_range(0.0, 1.0) var spew_shake_mult : float = 0.6
@export_range(0.0, 1.0) var spew_intensity_range : float = 0.6
@export_range(0.0, 1.0) var spew_text_flicker_chance : float = 0.4
@export var spew_text_flicker_alpha : Vector2 = Vector2(0.3, 0.8)
@export_range(0.0, 1.0) var spew_strobe_chance : float = 0.35
@export_range(0.0, 1.0) var spew_strobe_alpha : float = 0.25
@export var spew_strobe_color : Color = Color(1.0, 0.0, 0.0)

@export_subgroup("Fuel Empty (sputter)")
@export var sputter_time : float = 2.2
@export var sputter_frequency : float = 70.0
@export var sputter_threshold_base : float = -0.4
@export var sputter_threshold_slope : float = 0.9
@export_range(0.0, 1.0) var sputter_on_intensity : float = 0.4
@export_range(0.0, 1.0) var sputter_off_intensity : float = 0.05
@export_range(0.0, 1.0) var sputter_off_text_alpha : float = 0.35
@export_range(0.0, 1.0) var sputter_off_blackout : float = 0.5
@export_range(0.0, 1.0) var sputter_shake_mult : float = 0.5

@export_subgroup("Quota Missed (tick)")
@export var tick_time : float = 1.6
@export var tick_steps : int = 30
@export_range(0.0, 1.0) var tick_glitch_chance : float = 0.15
@export var tick_glitch_offset : float = 10.0
@export_range(0.0, 1.0) var tick_glitch_flash_alpha : float = 0.12
@export_range(0.0, 1.0) var tick_intensity_base : float = 0.5
@export_range(0.0, 1.0) var tick_intensity_gain : float = 0.3

@export_group("Phase 2 : Reveal")
@export_subgroup("Blackout")
@export var blackout_hold : float = 0.6

@export_subgroup("Reveal")
@export var reveal_flash_fade : float = 0.5
@export var backdrop_fade_time : float = 0.3
@export_range(0.0, 1.0) var backdrop_text_alpha : float = 0.25
@export_range(0.0, 1.0) var backdrop_intensity : float = 0.3
@export var window_open_time : float = 0.5
@export var title_fade_time : float = 0.3
@export var title_slam_time : float = 0.35
@export var title_start_scale : float = 1.15
@export var tag_fade_time : float = 0.2
@export var pause_before_sub : float = 0.2
@export var sub_type_time : float = 0.8
@export var score_fade_time : float = 0.15
@export var score_count_time : float = 0.8
@export var summary_type_time : float = 1.0
@export var end_pause : float = 0.3

@export_subgroup("Slam")
@export_range(0.0, 1.0) var slam_flash_alpha : float = 0.7
@export var slam_flash_fade : float = 0.25
@export var slam_shake_time : float = 0.45

@export_subgroup("Tag Blink")
@export var blink_time : float = 0.5
@export_range(0.0, 1.0) var blink_min_alpha : float = 0.25

@export_subgroup("Calm Mode (photosensitive)")
@export var calm_reveal_time : float = 1.8
@export var calm_fade_to_black : float = 0.5
@export var calm_flash_fade : float = 0.6
@export var calm_title_start_scale : float = 1.05
@export_range(0.0, 1.0) var calm_intensity_start : float = 0.2
@export_range(0.0, 1.0) var calm_intensity_gain : float = 0.1

var _tween : Tween
var _blink : Tween
var _shake_strength : float = 0.0
var _calm : bool = false
var _dim : float = 1.0
var _tag_text : String = ""
var _title_text : String = ""
@onready var _layout : Control = get_node_or_null("Layout")

func _ready() -> void:
	hide()
	resized.connect(_update_focal_point)
	_update_focal_point()

func _update_focal_point() -> void:
	if backdrop:
		backdrop.focal_point = size * 0.5

func _tint(color : Color) -> void:
	for node in find_children("*", "HangarPlate", true, false):
		(node as HangarPlate).accent_color = color

func _config(reason : int) -> Dictionary:
	match reason:
		DataCollector.EndReason.MELTDOWN:
			return {"title": "CRITICAL MELTDOWN", "sub": "REACTOR MELTDOWN - EVACUATE",
				"tag": "// HULL INTEGRITY 0% //", "color": MenuStyle.DANGER, "shake": shake_meltdown}
		DataCollector.EndReason.FUEL_EMPTY:
			return {"title": "OUT OF FUEL", "sub": "PROPELLANT EMPTY - JOIN THE ABYSS",
				"tag": "// FUEL RESERVES 0% //", "color": MenuStyle.WARNING, "shake": shake_default}
	return {"title": "QUOTA MISSED", "sub": "THE COLLECTIVE IS NOT IMPRESSED",
		"tag": "// TIME EXPIRED //", "color": MenuStyle.ACCENT, "shake": shake_default}

func _player() -> Player:
	if not is_instance_valid(DataCollector.player):
		return null
	return DataCollector.player

func _music_begin(reason : int) -> void:
	var p := _player()
	if p:
		p.begin_end_music(reason)

func _music_progress(t : float) -> void:
	var p := _player()
	if p:
		p.set_end_music_progress(t)

func _music_death() -> void:
	var p := _player()
	if p:
		p.end_music_death()

func _music_aftermath() -> void:
	var p := _player()
	if p:
		p.end_music_aftermath()

func _restore_music() -> void:
	var p := _player()
	if p:
		p.restore_music()

func play(reason : int, final_score : int, quota : int) -> void:
	_calm = Settings.photosensitive()
	var cfg := _config(reason)
	var color : Color = cfg["color"]
	_shake_strength = cfg["shake"] * Settings.shake_scale()
	_tag_text = cfg["tag"]
	_title_text = cfg["title"]

	_kill_tweens()
	_reset_fx()
	_music_begin(reason)
	modulate.a = 0.0
	show()

	overlay.tint = color
	_set_intensity(0.0)
	_set_flash(Color(0, 0, 0, 0))

	tag.text = _tag_text
	tag.add_theme_color_override("font_color", color)
	tag.modulate.a = 0.0
	title.text = _title_text
	title.modulate.a = 0.0
	title.add_theme_color_override("font_shadow_color", Color(color, 0.55))
	_tint(color)
	_update_focal_point()
	progress_bar.value = 0.0
	title.scale = Vector2.ONE * (calm_title_start_scale if _calm else title_start_scale)
	sub.text = cfg["sub"]
	sub.visible_ratio = 0.0
	score.text = ""
	score.modulate.a = 0.0
	summary_lbl.text = _format_summary()
	summary_lbl.visible_ratio = 0.0
	overlow.text = (PAYLOAD + "\n").repeat(payload_repeats) + PAYLOAD_TAIL
	overlow.visible_ratio = 0.0
	overlow.modulate.a = 1.0
	backpanel.modulate.a = 0.0

	await get_tree().process_frame
	pivot_offset = size / 2.0
	title.pivot_offset = Vector2(0.0, title.size.y / 2.0)

	# The failure console fades in over the game instead of appearing in one frame.
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_in_time)
	_tween.parallel().tween_property(overlay, "intensity", intro_intensity, fade_in_time)
	_build_death(reason)
	_build_reveal(final_score, quota)

func _reset_fx() -> void:
	position = Vector2.ZERO
	scale = Vector2.ONE
	_dim = 1.0
	if _layout:
		_layout.position = Vector2.ZERO

# Each ending dies differently, then fades to black before the results come up.
func _build_death(reason : int) -> void:
	var to_black := death_fade
	if _calm:
		_tween.tween_method(_calm_spew, 0.0, 1.0, calm_reveal_time)
		to_black = calm_fade_to_black
	elif reason == DataCollector.EndReason.MELTDOWN:
		# Errors and viruses pile up faster and faster, then the screen collapses like a dying CRT.
		_tween.tween_method(_spew, 0.0, 1.0, spew_time) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		_tween.tween_method(_crash, 0.0, 1.0, crash_time)
		to_black = 0.08
	elif reason == DataCollector.EndReason.FUEL_EMPTY:
		# An engine starving for fuel: misfires get slower and deeper until it quits.
		_tween.tween_method(_sputter, 0.0, 1.0, sputter_time)
	else:
		# Quota missed: a plain, steady countdown with no glitching.
		_tween.tween_method(_tick, 0.0, 1.0, tick_time)

	_tween.tween_property(flash, "color", Color(0, 0, 0, 1), to_black)
	_tween.tween_callback(_death)
	_tween.tween_interval(blackout_hold)

func _build_reveal(final_score : int, quota : int) -> void:
	var fade := calm_flash_fade if _calm else reveal_flash_fade
	_tween.tween_callback(_music_aftermath)
	_tween.tween_property(flash, "color:a", 0.0, fade)
	_tween.parallel().tween_property(overlow, "modulate:a", backdrop_text_alpha, backdrop_fade_time)
	_tween.parallel().tween_property(overlay, "intensity", backdrop_intensity, backdrop_fade_time)
	_tween.parallel().tween_property(backpanel, "modulate:a", 1.0, window_open_time)
	_tween.tween_callback(_slam)
	_tween.tween_property(title, "modulate:a", 1.0, title_fade_time)
	_tween.parallel().tween_property(title, "scale", Vector2.ONE, title_slam_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(tag, "modulate:a", 1.0, tag_fade_time)
	_tween.tween_interval(pause_before_sub)
	_tween.tween_property(sub, "visible_ratio", 1.0, sub_type_time)
	_tween.tween_property(score, "modulate:a", 1.0, score_fade_time)
	_tween.tween_method(_set_score.bind(final_score, quota), 0.0, 1.0, score_count_time)
	_tween.tween_property(summary_lbl, "visible_ratio", 1.0, summary_type_time)
	_tween.tween_interval(end_pause)
	_tween.tween_callback(_finish)

#region Death effects
const GLITCH_GLYPHS := "░▒▓█#%&@0123456789"

func _garble(text : String, amount : float) -> String:
	var out := ""
	for character in text:
		out += GLITCH_GLYPHS[randi() % GLITCH_GLYPHS.length()] if character != " " and randf() < amount else character
	return out

# MELTDOWN: errors flood in, the layout tears sideways, text and gauge corrupt.
func _spew(t : float) -> void:
	_music_progress(t)
	overlow.visible_ratio = t
	position = _jitter(_shake_strength * spew_shake_mult * t)
	_set_intensity(intro_intensity + randf() * spew_intensity_range * t)
	overlow.modulate.a = 1.0 if randf() > t * spew_text_flicker_chance \
		else randf_range(spew_text_flicker_alpha.x, spew_text_flicker_alpha.y)
	if randf() < t * spew_strobe_chance:
		_set_flash(Color(spew_strobe_color, randf() * spew_strobe_alpha * t))
	else:
		_set_flash(Color(0, 0, 0, 0))
	if _layout:
		_layout.position.x = randf_range(-60.0, 60.0) * t if randf() < t * 0.6 else 0.0
	progress_bar.value = randf() * t if randf() < 0.5 else 1.0 - t
	tag.modulate.a = minf(t * 4.0, 1.0)
	tag.text = _garble(_tag_text, t * 0.6)
	title.modulate.a = minf(t * 4.0, 1.0)
	title.scale = Vector2.ONE
	title.text = _garble(_title_text, t * 0.8)

# Last moment of a dying monitor: the picture squeezes to a line, then a dot.
func _crash(t : float) -> void:
	overlow.modulate.a = 0.0
	position = Vector2.ZERO
	if _layout:
		_layout.position = Vector2.ZERO
	scale = Vector2(maxf(1.0 - smoothstep(0.6, 1.0, t), 0.002), maxf(1.0 - smoothstep(0.0, 0.6, t), 0.004))
	_set_intensity(lerpf(0.9, 0.2, t))

# FUEL_EMPTY: engine misfire. Brightness dips softly, the fuel gauge drains and flickers.
func _sputter(t : float) -> void:
	_music_progress(t)
	var engine_on := sin(t * sputter_frequency * (1.0 - 0.6 * t)) > sputter_threshold_base + t * sputter_threshold_slope
	var previous_dim := _dim
	_dim = lerpf(_dim, 1.0 if engine_on else 0.08, 0.4)
	overlow.visible_ratio = t
	overlow.modulate.a = lerpf(sputter_off_text_alpha, 1.0, _dim)
	_set_intensity(lerpf(sputter_off_intensity, sputter_on_intensity, _dim))
	_set_flash(Color(0, 0, 0, (1.0 - _dim) * sputter_off_blackout))
	position = _jitter(_shake_strength * sputter_shake_mult * (1.0 - t) * clampf(absf(_dim - previous_dim) * 6.0, 0.0, 1.0))
	progress_bar.value = (1.0 - t) * lerpf(0.5, 1.0, _dim)
	tag.modulate.a = _dim
	title.modulate.a = 0.0

# QUOTA MISSED: calm, steady ticks as time runs out.
func _tick(t : float) -> void:
	_music_progress(t)
	var stepped := floorf(t * tick_steps) / tick_steps
	overlow.visible_ratio = stepped
	progress_bar.value = 1.0 - stepped
	_set_intensity(tick_intensity_base + tick_intensity_gain * t)

func _calm_spew(t : float) -> void:
	_music_progress(t)
	overlow.visible_ratio = t
	progress_bar.value = 1.0 - t
	_set_intensity(calm_intensity_start + calm_intensity_gain * t)

# Runs under the black fade: puts everything back so the results can fade in clean.
func _death() -> void:
	_music_death()
	_reset_fx()
	_set_intensity(0.0)
	overlow.modulate.a = 0.0
	tag.text = _tag_text
	tag.modulate.a = 0.0
	title.text = _title_text
	title.modulate.a = 0.0
	title.scale = Vector2.ONE * (calm_title_start_scale if _calm else title_start_scale)
	progress_bar.value = 0.0

func _slam() -> void:
	if not _calm:
		backdrop.trigger_pulse()
#endregion

func _shake(s : float) -> void:
	position = _jitter(_shake_strength * s)

func _set_score(t : float, final_score : int, quota : int) -> void:
	var text := "SCORE  %d / %d" % [roundi(final_score * t), quota]
	if t >= 1.0 and final_score < quota:
		text += "\nSHORT BY %d" % (quota - final_score)
	score.text = text
	progress_bar.value = clampf(final_score * t / maxf(quota, 1.0), 0.0, 1.0)

func _finish() -> void:
	if not _calm:
		_blink = create_tween().set_loops()
		_blink.tween_property(tag, "modulate:a", blink_min_alpha, blink_time)
		_blink.tween_property(tag, "modulate:a", 1.0, blink_time)
	sequence_finished.emit()

func stop() -> void:
	_kill_tweens()
	position = Vector2.ZERO
	_restore_music()
	hide()

func _kill_tweens() -> void:
	if _tween: _tween.kill()
	if _blink: _blink.kill()

func _jitter(amount : float) -> Vector2:
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount

func _set_flash(c : Color) -> void:
	flash.color = c

func _set_intensity(v : float) -> void:
	overlay.intensity = v

func _format_summary() -> String:
	var p := DataCollector.player as Player
	if p == null or not is_instance_valid(p):
		return ""

	var s : Dictionary = p.get_summary()
	var t : float = float(s.get("time", 0.0))

	var lines : PackedStringArray = [
		"DEBRIS COLLECTED  %d  (DELIVERED %d)" % [
			int(s.get("debris_collected", 0)),
			int(s.get("debris_delivered", 0))
		],
		"TIME  %d:%02d" % [int(t) / 60, int(t) % 60],
		"DISTANCE  %d" % roundi(float(s.get("distance", 0.0))),
		"TOP SPEED  %d   AVG  %d" % [
			roundi(float(s.get("top_speed", 0.0))),
			roundi(float(s.get("avg_speed", 0.0)))
		],
		"CRASHES  %d" % int(s.get("crashes", 0)),
		"PEAK LOAD  %.1f" % float(s.get("peak_load", 0.0)),
		"FUEL BURNED  %d" % roundi(float(s.get("fuel_burned", 0.0))),
		"PEAK HEAT  %d%%" % roundi(float(s.get("peak_heat_pct", 0.0))),
		"BOOST TIME  %.1fs" % float(s.get("boost_time", 0.0)),
	]

	return "\n".join(lines)