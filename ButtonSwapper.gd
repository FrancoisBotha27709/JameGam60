@tool
extends EditorScript

const BB := "res://Assets/Nodes/better_button.tscn"
const DRY := false
const BTN := "HBoxContainer/Control/Button"
const LBL := "HBoxContainer/Control/RichTextLabel"
const LEFT := "HBoxContainer/LeftTexture"
const LAYOUT := ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "offset_left", "offset_top", "offset_right", "offset_bottom", "grow_horizontal", "grow_vertical", "custom_minimum_size", "size_flags_horizontal", "size_flags_vertical", "size_flags_stretch_ratio", "rotation", "visible", "tooltip_text", "layout_direction", "z_index"]
const BTN_PROPS := ["toggle_mode", "button_pressed", "action_mode", "button_mask", "keep_pressed_outside", "shortcut", "shortcut_in_tooltip", "focus_mode", "mouse_default_cursor_shape", "flat"]

func _run() -> void:
	EditorInterface.save_all_scenes()
	var bb: PackedScene = load(BB)
	var files: Array[String] = []
	_walk("res://", files)
	var total := 0
	for f in files:
		if f != BB:
			total += _scene(f, bb)
	print("BetterButton walker: ", total, " buttons ", "found (dry run)" if DRY else "replaced")
	if not DRY and total > 0:
		EditorInterface.get_resource_filesystem().scan()
		for p in EditorInterface.get_open_scenes():
			EditorInterface.reload_scene_from_path(p)

func _walk(d: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".tscn"):
			out.append(d.path_join(f))
	for s in DirAccess.get_directories_at(d):
		if s.begins_with(".") or (d == "res://" and s == "addons"):
			continue
		_walk(d.path_join(s), out)

func _scene(path: String, bb: PackedScene) -> int:
	var ps := load(path) as PackedScene
	if ps == null or ps.get_state().get_base_scene_state() != null:
		return 0
	var root := ps.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var holders: Array[Node] = [root]
	for n in root.find_children("*", "", true, false):
		if n.owner == root:
			holders.append(n)
	var buttons: Array[Node] = []
	for n in holders:
		if n != root and n.get_class() == "Button" and n.get_script() == null and n.scene_file_path == "":
			buttons.append(n)
	if buttons.is_empty() or DRY:
		if not buttons.is_empty():
			print(path, ": ", buttons.size())
		root.free()
		return buttons.size()
	var recs := []
	for h in holders:
		for p in h.get_property_list():
			if not (p.usage & PROPERTY_USAGE_STORAGE):
				continue
			var isp: bool = p.type == TYPE_NODE_PATH
			if not isp and p.type != TYPE_OBJECT:
				continue
			var v = h.get(p.name)
			var t: Node = null
			if isp:
				if not v.is_empty():
					t = h.get_node_or_null(v)
			elif v is Node:
				t = v
			var i := buttons.find(t)
			if i >= 0:
				recs.append([h, p.name, isp, i])
	var inners: Array[Node] = []
	for b in buttons:
		inners.append(_swap(root, b as Button, bb))
	for r in recs:
		var h = r[0]
		if is_instance_valid(h):
			var inner: Node = inners[r[3]]
			h.set(r[1], h.get_path_to(inner) if r[2] else inner)
	if ps.pack(root) == OK:
		ResourceSaver.save(ps, path)
	root.free()
	print(path, ": ", buttons.size())
	return buttons.size()

func _swap(root: Node, old: Button, bb: PackedScene) -> Node:
	var parent := old.get_parent()
	var idx := old.get_index()
	var nm := old.name
	var uniq := old.unique_name_in_owner
	var kept: Array[Node] = []
	for d in old.find_children("*", "", true, false):
		if d.owner == root:
			kept.append(d)
	var inst := bb.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Control
	parent.add_child(inst)
	parent.move_child(inst, idx)
	inst.owner = root
	root.set_editable_instance(inst, true)
	var btn := inst.get_node(BTN) as Button
	var lbl := inst.get_node(LBL) as RichTextLabel
	for p in LAYOUT:
		inst.set(p, old.get(p))
	inst.set("text", old.text.replace("[", "[lb]"))
	inst.set("disabled", old.disabled)
	for p in BTN_PROPS:
		btn.set(p, old.get(p))
	for p in old.get_property_list():
		if p.name.begins_with("theme_override_") and (p.usage & PROPERTY_USAGE_STORAGE):
			btn.set(p.name, old.get(p.name))
	lbl.set("horizontal_alignment", old.alignment)
	lbl.set("vertical_alignment", 1)
	lbl.set("autowrap_mode", old.autowrap_mode)
	if old.has_theme_font_size_override("font_size"):
		lbl.add_theme_font_size_override("normal_font_size", old.get_theme_font_size("font_size"))
	if old.has_theme_color_override("font_color"):
		lbl.add_theme_color_override("default_color", old.get_theme_color("font_color"))
	if old.has_theme_font_override("font"):
		lbl.add_theme_font_override("normal_font", old.get_theme_font("font"))
	if old.icon:
		inst.get_node(LEFT).set("texture", old.icon)
	for s in old.get_signal_list():
		for c in old.get_signal_connection_list(s.name):
			if (c.flags & CONNECT_PERSIST) and c.callable.get_object() != old:
				var src: Object = inst if s.name == "pressed" else btn
				src.connect(s.name, c.callable, c.flags)
	for g in old.get_groups():
		if not str(g).begins_with("_"):
			inst.add_to_group(g, true)
	for m in old.get_meta_list():
		inst.set_meta(m, old.get_meta(m))
	for c in old.get_children():
		c.reparent(inst, false)
	for d in kept:
		d.owner = root
	parent.remove_child(old)
	old.free()
	inst.name = nm
	inst.unique_name_in_owner = uniq
	return btn