extends CanvasLayer
class_name TouchesHUDDisplayer

@export var actif: bool = true

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		visible = v
	get:
		return _ui_visible

@export_group("Touches affichées")
@export var actions_affichees: Array[Dictionary] = [
	{"action": "gauche", "label": "Gauche"},
	{"action": "droite", "label": "Droite"},
	{"action": "haut", "label": "Haut"},
	{"action": "bas", "label": "Bas"},
	{"action": "ramasser", "label": "Ramasser"},
	{"action": "dash", "label": "Dash + Interragir"},
	{"action": "attaque_main_gauche", "label": "Attaque G"},
	{"action": "attaque_main_droite", "label": "Attaque D"},
	{"action": "pause", "label": "Pause"}
]

@export_group("Placement")
@export var marge_bas_px: float = 18.0

@export_group("Style")
@export var fond_barre: Color = Color(0, 0, 0, 0.40)
@export var fond_touche: Color = Color(0, 0, 0, 0.55)
@export var bordure: Color = Color(1, 1, 1, 0.20)
@export var texte: Color = Color(1, 1, 1, 0.92)
@export var espace_px: int = 10
@export var padding_x: int = 10
@export var padding_y: int = 8
@export var largeur_min_touche_px: float = 62.0
@export_range(10, 42, 1) var taille_police_touche: int = 16
@export_range(8, 28, 1) var taille_police_label: int = 12

@export_group("Animation")
@export var anim_scale: float = 1.12
@export var anim_up_s: float = 0.06
@export var anim_down_s: float = 0.10
@export var anim_flash_alpha: float = 1.0
@export var idle_alpha: float = 0.88

@export_group("Raccourcis")
@export var toggle_key: Key = KEY_F3

@export_group("Perf")
@export var maj_binds_interval_s: float = 0.25

var _bar: PanelContainer
var _hbox: HBoxContainer

var _sb_bar: StyleBoxFlat
var _sb_item: StyleBoxFlat

var _items: Dictionary = {}
var _t_binds: float = 0.0
var _last_viewport_size: Vector2 = Vector2.ZERO
var _last_bar_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	_ui_visible = ui_visible
	_creer_ui()
	_maj_binds(true)
	_relayout(true)
	visible = _ui_visible

func _process(dt: float) -> void:
	if not actif:
		return

	_t_binds += dt
	if _t_binds >= max(maj_binds_interval_s, 0.02):
		_t_binds = 0.0
		_maj_binds(false)

	for action_name in _items.keys():
		var a: StringName = action_name as StringName
		if Input.is_action_just_pressed(a):
			_jouer_anim(a)

	_relayout(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == toggle_key:
			ui_visible = not ui_visible

func _creer_ui() -> void:
	_bar = PanelContainer.new()
	add_child(_bar)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hbox = HBoxContainer.new()
	_bar.add_child(_hbox)
	_hbox.add_theme_constant_override("separation", espace_px)

	if _sb_bar == null:
		_sb_bar = StyleBoxFlat.new()
	_sb_bar.bg_color = fond_barre
	_sb_bar.border_color = bordure
	_sb_bar.border_width_left = 1
	_sb_bar.border_width_right = 1
	_sb_bar.border_width_top = 1
	_sb_bar.border_width_bottom = 1
	_sb_bar.corner_radius_top_left = 8
	_sb_bar.corner_radius_top_right = 8
	_sb_bar.corner_radius_bottom_left = 8
	_sb_bar.corner_radius_bottom_right = 8
	_bar.add_theme_stylebox_override("panel", _sb_bar)

	if _sb_item == null:
		_sb_item = StyleBoxFlat.new()
	_sb_item.bg_color = fond_touche
	_sb_item.border_color = bordure
	_sb_item.border_width_left = 1
	_sb_item.border_width_right = 1
	_sb_item.border_width_top = 1
	_sb_item.border_width_bottom = 1
	_sb_item.corner_radius_top_left = 6
	_sb_item.corner_radius_top_right = 6
	_sb_item.corner_radius_bottom_left = 6
	_sb_item.corner_radius_bottom_right = 6

	_items.clear()
	for d in actions_affichees:
		var action_str: String = String(d.get("action", ""))
		if action_str.is_empty():
			continue
		var action_name: StringName = StringName(action_str)
		var label_txt: String = String(d.get("label", action_str))

		var item_panel := PanelContainer.new()
		item_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_panel.custom_minimum_size = Vector2(largeur_min_touche_px, 0.0)
		item_panel.modulate.a = idle_alpha
		item_panel.add_theme_stylebox_override("panel", _sb_item)
		_hbox.add_child(item_panel)

		var v := VBoxContainer.new()
		item_panel.add_child(v)
		v.add_theme_constant_override("separation", 0)

		var lbl_key := Label.new()
		lbl_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_key.add_theme_font_size_override("font_size", taille_police_touche)
		lbl_key.add_theme_color_override("font_color", texte)
		v.add_child(lbl_key)

		var lbl_action := Label.new()
		lbl_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_action.text = label_txt
		lbl_action.add_theme_font_size_override("font_size", taille_police_label)
		lbl_action.add_theme_color_override("font_color", texte)
		v.add_child(lbl_action)

		var margin := MarginContainer.new()
		item_panel.remove_child(v)
		item_panel.add_child(margin)
		margin.add_child(v)
		margin.add_theme_constant_override("margin_left", padding_x)
		margin.add_theme_constant_override("margin_right", padding_x)
		margin.add_theme_constant_override("margin_top", padding_y)
		margin.add_theme_constant_override("margin_bottom", padding_y)

		_items[action_name] = {
			"panel": item_panel,
			"lbl_key": lbl_key,
			"lbl_action": lbl_action,
			"tween": null,
			"last_bind": ""
		}

	call_deferred("_maj_pivots")

func _maj_pivots() -> void:
	for a in _items.keys():
		var item: Dictionary = _items[a] as Dictionary
		var p: Control = item["panel"] as Control
		if is_instance_valid(p):
			p.pivot_offset = p.size * 0.5

func _maj_binds(force: bool) -> void:
	for a in _items.keys():
		var item: Dictionary = _items[a] as Dictionary
		var lbl_key: Label = item["lbl_key"] as Label
		var bind_txt: String = _get_action_text(a as StringName)

		var last_bind: String = String(item.get("last_bind", ""))
		if force or bind_txt != last_bind:
			item["last_bind"] = bind_txt
			_items[a] = item
			if is_instance_valid(lbl_key):
				lbl_key.text = bind_txt

func _get_action_text(nom_action: StringName) -> String:
	if not InputMap.has_action(nom_action):
		return "—"
	var evts: Array[InputEvent] = InputMap.action_get_events(nom_action)
	if evts.is_empty():
		return "—"

	var best: InputEvent = null
	for e in evts:
		if e is InputEventKey:
			best = e
			break
	for e in evts:
		if best != null:
			break
		if e is InputEventMouseButton:
			var mb := e as InputEventMouseButton
			if not mb.double_click:
				best = e
				break
	if best == null:
		best = evts[0]

	return _format_event(best)

func _format_event(e: InputEvent) -> String:
	if e == null:
		return "—"

	if e is InputEventKey:
		var k := e as InputEventKey
		var code: Key = k.keycode
		if int(code) == 0 and k.physical_keycode != 0:
			code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		var s := OS.get_keycode_string(code)
		if s.is_empty():
			s = e.as_text()
		return s

	if e is InputEventMouseButton:
		var m := e as InputEventMouseButton
		var base := ""
		if m.button_index == MOUSE_BUTTON_LEFT:
			base = "LMB"
		elif m.button_index == MOUSE_BUTTON_RIGHT:
			base = "RMB"
		elif m.button_index == MOUSE_BUTTON_MIDDLE:
			base = "MMB"
		elif m.button_index == MOUSE_BUTTON_WHEEL_UP:
			base = "WHEEL↑"
		elif m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			base = "WHEEL↓"
		else:
			base = "MOUSE%d" % int(m.button_index)

		if m.double_click:
			return base + "×2"
		return base

	if e is InputEventJoypadButton:
		var j := e as InputEventJoypadButton
		return "PAD %d" % int(j.button_index)

	return e.as_text()

func _jouer_anim(action_name: StringName) -> void:
	var item: Dictionary = _items.get(action_name, {}) as Dictionary
	if item.is_empty():
		return

	var p: Control = item["panel"] as Control
	if not is_instance_valid(p):
		return

	var t: Tween = item.get("tween", null) as Tween
	if t != null and is_instance_valid(t):
		t.kill()

	p.pivot_offset = p.size * 0.5
	p.scale = Vector2.ONE
	p.modulate.a = idle_alpha

	var tw := create_tween()
	item["tween"] = tw
	_items[action_name] = item

	tw.tween_property(p, "modulate:a", anim_flash_alpha, 0.03)
	tw.parallel().tween_property(p, "scale", Vector2(anim_scale, anim_scale), max(anim_up_s, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "scale", Vector2.ONE, max(anim_down_s, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(p, "modulate:a", idle_alpha, 0.08)

func _relayout(force: bool) -> void:
	if _bar == null:
		return

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size == Vector2.ZERO:
		return

	var need: bool = force
	if vp_size != _last_viewport_size:
		need = true
	if _bar.size != _last_bar_size:
		need = true

	if not need:
		return

	_last_viewport_size = vp_size
	_last_bar_size = _bar.size

	var x := (vp_size.x - _bar.size.x) * 0.5
	var y := vp_size.y - marge_bas_px - _bar.size.y

	_bar.position = Vector2(max(x, 0.0), max(y, 0.0))
