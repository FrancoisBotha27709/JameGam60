extends Control
class_name RunEndBanner

signal sequence_finished

## Padding to make the error label look more techy. The cut-off tail is appended once at the very end.
const PAYLOAD : String = "[color=red][ ERROR ] [/color] Memory buffer overflow
[color=red][ ERROR ] [/color] Stack corruption detected
[color=yellow][ WARN ] [/color] CPU temp critical: 98C
[color=red][ ERROR ] [/color] Page fault in kernel space
[color=red][ ERROR ] [/color] Heap allocation failed
[color=yellow][ WARN ] [/color] Fan speed 0 RPM
[color=red][ ERROR ] [/color] Segmentation fault
[color=red][ ERROR ] [/color] Disk I/O timeout
[color=red][ ERROR ] [/color] Filesystem journal corrupted
[color=yellow][ WARN ] [/color] Swap space exhausted
[color=red][ ERROR ] [/color] Process 1337 unresponsive
[color=red][ ERROR ] [/color] Kernel panic: unable to sync
[color=red][ ERROR ] [/color] Watchdog timer expired
[color=red][ ERROR ] [/color] NULL pointer dereference
[color=yellow][ WARN ] [/color] Voltage drop on 3.3V rail
[color=red][ ERROR ] [/color] Network stack failure
[color=red][ ERROR ] [/color] DNS resolver crashed
[color=red][ ERROR ] [/color] Packet checksum mismatch
[color=red][ ERROR ] [/color] Cache coherency violation
[color=red][ ERROR ] [/color] Interrupt storm on IRQ 7
[color=yellow][ WARN ] [/color] Thermal throttle ignored
[color=red][ ERROR ] [/color] GPU driver hung
[color=red][ ERROR ] [/color] Framebuffer unmapped
[color=red][ ERROR ] [/color] Mutex deadlock detected
[color=red][ ERROR ] [/color] Race condition in scheduler
[color=red][ ERROR ] [/color] Bootloader signature invalid
[color=red][ ERROR ] [/color] RAID array degraded
[color=red][ ERROR ] [/color] Sector 0x00FF unreadable
[color=red][ ERROR ] [/color] Encryption keys lost
[color=yellow][ WARN ] [/color] Backup power failing
[color=red][ ERROR ] [/color] Double fault exception
[color=red][ ERROR ] [/color] Recovery routine failed
[color=red][ ERROR ] [/color] Recovery routine failed
[color=red][ ERROR ] [/color] Recovery routine failed
[color=red][ ERROR ] [/color] Kernel module unload failed
[color=red][ ERROR ] [/color] Orphaned process tree
[color=red][ ERROR ] [/color] Zombie process overflow
[color=yellow][ WARN ] [/color] File descriptors exhausted
[color=red][ ERROR ] [/color] Socket bind failed
[color=red][ ERROR ] [/color] Connection reset by peer
[color=red][ ERROR ] [/color] TLS handshake aborted
[color=red][ ERROR ] [/color] Certificate chain invalid
[color=red][ ERROR ] [/color] Authentication daemon dead
[color=red][ ERROR ] [/color] Privilege escalation blocked
[color=yellow][ WARN ] [/color] Unauthorized memory access
[color=red][ ERROR ] [/color] Syscall table modified
[color=red][ ERROR ] [/color] Kernel integrity check failed
[color=red][ ERROR ] [/color] ACPI table corrupted
[color=red][ ERROR ] [/color] BIOS checksum error
[color=red][ ERROR ] [/color] CMOS battery dead
[color=yellow][ WARN ] [/color] System clock drift: +4382s
[color=red][ ERROR ] [/color] Timer interrupt lost
[color=red][ ERROR ] [/color] Scheduler queue overflow
[color=red][ ERROR ] [/color] Context switch failed
[color=red][ ERROR ] [/color] Thread pool exhausted
[color=red][ ERROR ] [/color] Pipe broken
[color=red][ ERROR ] [/color] Buffer underrun
[color=red][ ERROR ] [/color] Buffer overrun
[color=red][ ERROR ] [/color] Unhandled exception 0xC0000005
[color=red][ ERROR ] [/color] Unhandled exception 0xC0000094
[color=red][ ERROR ] [/color] Unhandled exception 0xDEADBEEF
[color=yellow][ WARN ] [/color] Disk SMART status: FAILING
[color=red][ ERROR ] [/color] Bad block count: 40960
[color=red][ ERROR ] [/color] Inode table destroyed
[color=red][ ERROR ] [/color] Superblock invalid
[color=red][ ERROR ] [/color] Mount failed: /home
[color=red][ ERROR ] [/color] Mount failed: /var
[color=red][ ERROR ] [/color] Mount failed: /boot
[color=red][ ERROR ] [/color] Mount failed: /
[color=yellow][ WARN ] [/color] Read-only filesystem forced
[color=red][ ERROR ] [/color] Write failed: no space left
[color=red][ ERROR ] [/color] Log rotation failed
[color=red][ ERROR ] [/color] Audit subsystem offline
[color=red][ ERROR ] [/color] Firewall rules purged
[color=red][ ERROR ] [/color] Intrusion detection offline
[color=yellow][ WARN ] [/color] Unknown device on PCI bus
[color=red][ ERROR ] [/color] PCI bus error
[color=red][ ERROR ] [/color] USB controller reset loop
[color=red][ ERROR ] [/color] Audio driver crashed
[color=red][ ERROR ] [/color] Input device lost
[color=red][ ERROR ] [/color] Display signal lost
[color=red][ ERROR ] [/color] VRAM corruption detected
[color=red][ ERROR ] [/color] Shader compile failed
[color=red][ ERROR ] [/color] Render pipeline stalled
[color=yellow][ WARN ] [/color] GPU temp critical: 112C
[color=red][ ERROR ] [/color] Voltage regulator fault
[color=red][ ERROR ] [/color] Power rail 12V unstable
[color=red][ ERROR ] [/color] Power rail 5V unstable
[color=red][ ERROR ] [/color] Power rail 3.3V collapsed
[color=yellow][ WARN ] [/color] Battery critical: 1%
[color=red][ ERROR ] [/color] Machine check exception
[color=red][ ERROR ] [/color] ECC uncorrectable error
[color=red][ ERROR ] [/color] ECC uncorrectable error
[color=red][ ERROR ] [/color] ECC uncorrectable error
[color=red][ ERROR ] [/color] DIMM 0 not responding
[color=red][ ERROR ] [/color] DIMM 1 not responding
[color=red][ ERROR ] [/color] DIMM 2 not responding
[color=red][ ERROR ] [/color] DIMM 3 not responding
[color=red][ ERROR ] [/color] Memory map destroyed
[color=red][ ERROR ] [/color] Triple fault imminent
[color=red][ ERROR ] [/color] Memory integrity c0rrupt3d
[color=red][ ERROR ] [/color] St4ck 0v3rfl0w
[color=red][ ERROR ] [/color] K3rn3l p4n1c
[color=red][ ERROR ] [/color] Ret_urn addr3ss ov3rwr1tt3n
[color=red][ ERROR ] [/color] ░▒▓█ SYSTEM UNSTABLE █▓▒░
[color=red][ ERROR ] [/color] ▓▒░ DATA LOSS IN PROGRESS ░▒▓
[color=red][ ERROR ] [/color] Cor3 t3mp3r4tur3 runaway
[color=red][ ERROR ] [/color] Thermal shutdown FAILED
[color=red][ ERROR ] [/color] Emergency halt FAILED
[color=red][ ERROR ] [/color] Emergency halt FAILED
[color=red][ ERROR ] [/color] Emergency halt FAILED
[color=red][ ERROR ] [/color] ERROR ERROR ERROR ERROR
[color=red][ ERROR ] [/color] ERROR ERROR ERROR ERROR
[color=red][ ERROR ] [/color] ERROR ERROR ERROR ERROR
[color=red][ ERROR ] [/color] 0x00000000 0x00000000 0x0000
[color=red][ ERROR ] [/color] ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
[color=red][ ERROR ] [/color] All processes terminated
[color=red][ ERROR ] [/color] All memory freed
[color=red][ ERROR ] [/color] All drives unmounted
[color=red][ ERROR ] [/color] Shutdown sequence failed
[color=red][ ERROR ] [/color] Power supply fail
"
const PAYLOAD_TAIL : String = "[color=red][ ERROR ] [/color] Power suppl
[color=red][ ERROR ] [/color] Pow
[color=red][ ERROR ] [/color] P
[color=red][ ERR"

@export_group("Nodes")
## Change this node's type in your scene from ColorRect to DitherVignette.
@export var overlay : DitherVignette
@export var backpanel : Panel
@export var tag : Label
@export var title : Label
@export var sub : Label
@export var score : Label
@export var flash : ColorRect
@export var overlow : RichTextLabel
@export var summary_lbl : Label

@export_group("Error Text")
@export_range(1, 10) var payload_repeats : int = 1
@export var shake_meltdown : float = 30.0
@export var shake_default : float = 14.0

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
@export var reveal_flash_fade : float = 0.15
@export var backdrop_fade_time : float = 0.3
@export_range(0.0, 1.0) var backdrop_text_alpha : float = 0.25
@export_range(0.0, 1.0) var backdrop_intensity : float = 0.3
@export var window_open_time : float = 0.3
@export var title_fade_time : float = 0.05
@export var title_slam_time : float = 0.35
@export var title_start_scale : float = 3.0
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
@export var calm_flash_fade : float = 0.4
@export var calm_title_start_scale : float = 1.2
@export_range(0.0, 1.0) var calm_intensity_start : float = 0.2
@export_range(0.0, 1.0) var calm_intensity_gain : float = 0.1

var _tween : Tween
var _blink : Tween
var _shake_strength : float = 0.0
var _calm : bool = false

func _config(reason : int) -> Dictionary:
	match reason:
		DataCollector.EndReason.MELTDOWN:
			return {"title": "CRITICAL MELTDOWN", "sub": "REACTOR MELTDOWN - EVACUATE",
				"tag": "// HULL INTEGRITY 0% //", "color": Color(1.0, 0.2, 0.15), "shake": shake_meltdown}
		DataCollector.EndReason.FUEL_EMPTY:
			return {"title": "OUT OF FUEL", "sub": "PROPELLANT EMPTY - JOIN THE ABYSS",
				"tag": "// FUEL RESERVES 0% //", "color": Color(1.0, 0.65, 0.1), "shake": shake_default}
	return {"title": "QUOTA MISSED", "sub": "THE COLLECTIVE IS NOT IMPRESSED",
		"tag": "// TIME EXPIRED //", "color": Color(0.3, 0.85, 1.0), "shake": shake_default}

func play(reason : int, final_score : int, quota : int) -> void:
	_calm = Settings.photosensitive()
	var cfg := _config(reason)
	var color : Color = cfg["color"]
	_shake_strength = cfg["shake"] * Settings.shake_scale()

	_kill_tweens()
	position = Vector2.ZERO
	show()

	overlay.tint = color
	_set_intensity(0.0)
	_set_flash(Color(0, 0, 0, 0))

	tag.text = cfg["tag"]
	tag.add_theme_color_override("font_color", color)
	tag.modulate.a = 0.0
	title.text = cfg["title"]
	title.add_theme_color_override("font_color", color)
	title.modulate.a = 0.0
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
	backpanel.scale = Vector2.ZERO

	await get_tree().process_frame
	title.pivot_offset = title.size / 2.0
	backpanel.pivot_offset = backpanel.size / 2.0

	_tween = create_tween()
	_tween.tween_property(overlay, "intensity", intro_intensity, intro_time)
	_build_death(reason)
	_build_reveal(final_score, quota)

func _build_death(reason : int) -> void:
	if _calm:
		_tween.tween_method(_calm_spew, 0.0, 1.0, calm_reveal_time)
		_tween.tween_property(flash, "color", Color(0, 0, 0, 1), calm_fade_to_black)
	elif reason == DataCollector.EndReason.MELTDOWN:
		_tween.tween_method(_spew, 0.0, 1.0, spew_time) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	elif reason == DataCollector.EndReason.FUEL_EMPTY:
		_tween.tween_method(_sputter, 0.0, 1.0, sputter_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_method(_tick, 0.0, 1.0, tick_time)

	_tween.tween_callback(_death)
	_tween.tween_interval(blackout_hold)

func _build_reveal(final_score : int, quota : int) -> void:
	var fade := calm_flash_fade if _calm else reveal_flash_fade
	_tween.tween_property(flash, "color:a", 0.0, fade)
	_tween.parallel().tween_property(overlow, "modulate:a", backdrop_text_alpha, backdrop_fade_time)
	_tween.parallel().tween_property(overlay, "intensity", backdrop_intensity, backdrop_fade_time)
	_tween.parallel().tween_property(backpanel, "scale", Vector2.ONE, window_open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_slam)
	_tween.tween_property(title, "modulate:a", 1.0, title_fade_time)
	_tween.parallel().tween_property(title, "scale", Vector2.ONE, title_slam_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(tag, "modulate:a", 1.0, tag_fade_time)
	_tween.tween_interval(pause_before_sub)
	_tween.tween_property(sub, "visible_ratio", 1.0, sub_type_time)
	_tween.tween_property(score, "modulate:a", 1.0, score_fade_time)
	_tween.tween_method(_set_score.bind(final_score, quota), 0.0, 1.0, score_count_time)
	_tween.tween_property(summary_lbl, "visible_ratio", 1.0, summary_type_time)
	_tween.tween_interval(end_pause)
	_tween.tween_callback(_finish)

func _spew(t : float) -> void:
	overlow.visible_ratio = t
	position = _jitter(_shake_strength * spew_shake_mult * t)
	_set_intensity(intro_intensity + randf() * spew_intensity_range * t)
	overlow.modulate.a = 1.0 if randf() > t * spew_text_flicker_chance \
		else randf_range(spew_text_flicker_alpha.x, spew_text_flicker_alpha.y)
	if randf() < t * spew_strobe_chance:
		_set_flash(Color(spew_strobe_color, randf() * spew_strobe_alpha * t))
	else:
		_set_flash(Color(0, 0, 0, 0))

func _sputter(t : float) -> void:
	overlow.visible_ratio = t
	var on := sin(t * sputter_frequency) > sputter_threshold_base + t * sputter_threshold_slope
	_set_intensity(sputter_on_intensity if on else sputter_off_intensity)
	overlow.modulate.a = 1.0 if on else sputter_off_text_alpha
	position = _jitter(_shake_strength * sputter_shake_mult * (1.0 - t))
	_set_flash(Color(0, 0, 0, 0.0 if on else sputter_off_blackout))

func _tick(t : float) -> void:
	overlow.visible_ratio = floorf(t * tick_steps) / tick_steps
	var glitch := randf() < tick_glitch_chance
	position = Vector2(randf_range(-tick_glitch_offset, tick_glitch_offset) if glitch else 0.0, 0.0)
	_set_intensity(tick_intensity_base + tick_intensity_gain * t)
	_set_flash(Color(1, 1, 1, tick_glitch_flash_alpha) if glitch else Color(0, 0, 0, 0))

func _calm_spew(t : float) -> void:
	overlow.visible_ratio = t
	_set_intensity(calm_intensity_start + calm_intensity_gain * t)

func _death() -> void:
	position = Vector2.ZERO
	_set_flash(Color(0, 0, 0, 1))
	_set_intensity(0.0)
	overlow.modulate.a = 0.0

func _slam() -> void:
	if _calm:
		return
	_set_flash(Color(1, 1, 1, slam_flash_alpha))
	var t := create_tween().set_parallel(true)
	t.tween_property(flash, "color:a", 0.0, slam_flash_fade)
	t.tween_method(_shake, 1.0, 0.0, slam_shake_time)

func _shake(s : float) -> void:
	position = _jitter(_shake_strength * s)

func _set_score(t : float, final_score : int, quota : int) -> void:
	var text := "SCORE  %d / %d" % [roundi(final_score * t), quota]
	if t >= 1.0 and final_score < quota:
		text += "\nSHORT BY %d" % (quota - final_score)
	score.text = text

func _finish() -> void:
	if not _calm:
		_blink = create_tween().set_loops()
		_blink.tween_property(tag, "modulate:a", blink_min_alpha, blink_time)
		_blink.tween_property(tag, "modulate:a", 1.0, blink_time)
	sequence_finished.emit()

func stop() -> void:
	_kill_tweens()
	position = Vector2.ZERO
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
	var p := DataCollector.player
	if p == null or not is_instance_valid(p):
		return ""
	var s : Dictionary = p.get_summary()
	var t : float = s["time"]
	var lines : PackedStringArray = [
		"DEBRIS COLLECTED  %d  (DELIVERED %d)" % [s["debris_collected"], s["debris_delivered"]],
		"TIME  %d:%02d" % [int(t) / 60, int(t) % 60],
		"DISTANCE  %d" % roundi(s["distance"]),
		"TOP SPEED  %d   AVG  %d" % [roundi(s["top_speed"]), roundi(s["avg_speed"])],
		"CRASHES  %d" % s["crashes"],
		"PEAK LOAD  %.1f" % s["peak_load"],
		"FUEL BURNED  %d" % roundi(s["fuel_burned"]),
		"PEAK HEAT  %d%%" % roundi(s["peak_heat_pct"]),
		"BOOST TIME  %.1fs" % s["boost_time"],
	]
	return "\n".join(lines)
