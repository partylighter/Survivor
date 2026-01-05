extends CanvasLayer
class_name EnemyCountDisplayer

@export var ui_visible: bool = true:
	set(v): _set_ui_visible(v)
	get: return _ui_visible

@export var actif: bool = true

@export_node_path("GestionnaireEnnemis") var chemin_ennemis: NodePath

@export var maj_interval_frames: int = 6:
	set(v): _set_maj_interval_frames(v)
	get: return _maj_interval_frames

@export var label_pos: Vector2 = Vector2(16, 16):
	set(v): _set_label_pos(v)
	get: return _label_pos

@export var label_scale: Vector2 = Vector2.ONE:
	set(v): _set_label_scale(v)
	get: return _label_scale

@export var label_z_index: int = 200:
	set(v): _set_label_z_index(v)
	get: return _label_z_index

@export var label_modulate: Color = Color(1, 1, 1, 1):
	set(v): _set_label_modulate(v)
	get: return _label_modulate

@export var label_name: StringName = &"EnemyCountLabel":
	set(v): _set_label_name(v)
	get: return _label_name

var _ui_visible: bool = true
var _maj_interval_frames: int = 6
var _label_pos: Vector2 = Vector2(16, 16)
var _label_scale: Vector2 = Vector2.ONE
var _label_z_index: int = 200
var _label_modulate: Color = Color(1, 1, 1, 1)
var _label_name: StringName = &"EnemyCountLabel"

@onready var ennemis_ref: GestionnaireEnnemis = get_node_or_null(chemin_ennemis) as GestionnaireEnnemis

var lbl: Label
var _frame: int = 0

func _ready() -> void:
	_ui_visible = ui_visible
	_maj_interval_frames = max(maj_interval_frames, 1)
	_label_pos = label_pos
	_label_scale = label_scale
	_label_z_index = label_z_index
	_label_modulate = label_modulate
	_label_name = label_name

	_creer_label_si_besoin()
	_appliquer_style_label()
	_set_ui_visible(_ui_visible)

func _process(_dt: float) -> void:
	if not actif or not visible:
		return

	_frame += 1
	if _frame < _maj_interval_frames:
		return
	_frame = 0

	if lbl == null:
		return

	if not is_instance_valid(ennemis_ref):
		lbl.text = "EnemyCountDisplayer: GestionnaireEnnemis invalide"
		return

	var total: int = ennemis_ref.ennemis.size()

	var full: int = 0
	var lite: int = 0
	var off: int = 0
	var invalid: int = 0

	for n: Node2D in ennemis_ref.ennemis:
		if not is_instance_valid(n):
			invalid += 1
			continue

		var mode: int = -1
		if n.has_meta("lod_mode"):
			var vv: Variant = n.get_meta("lod_mode")
			if typeof(vv) == TYPE_INT:
				mode = int(vv)

		match mode:
			0: full += 1
			1: lite += 1
			2: off += 1
			_: off += 1

	var full_limit: int = max(ennemis_ref.max_full_actifs, 0)
	var buffer_limit: int = max(ennemis_ref.max_buffer_actifs, full_limit)
	var lite_limit: int = max(0, buffer_limit - full_limit)

	var foule_actifs: int = 0
	if ennemis_ref.foule_actif:
		foule_actifs = ennemis_ref._foule_liste.size()

	lbl.text = ""
	lbl.text += "ENEMIS\n"
	lbl.text += "Total: " + str(total) + "   Invalid: " + str(invalid) + "\n"
	lbl.text += "FULL(LOD0): " + str(full) + " / " + str(full_limit) + "\n"
	lbl.text += "LITE(LOD1): " + str(lite) + " / " + str(lite_limit) + "\n"
	lbl.text += "OFF (LOD2): " + str(off) + "\n"
	lbl.text += "Foule actifs: " + str(foule_actifs) + " / budget " + str(ennemis_ref.foule_budget_par_frame)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			_set_ui_visible(!_ui_visible)

func _creer_label_si_besoin() -> void:
	lbl = null
	if has_node(NodePath(String(_label_name))):
		lbl = get_node(NodePath(String(_label_name))) as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = String(_label_name)
		add_child(lbl)

func _appliquer_style_label() -> void:
	if lbl == null:
		return
	lbl.position = _label_pos
	lbl.scale = _label_scale
	lbl.z_index = _label_z_index
	lbl.modulate = _label_modulate
	lbl.visible = _ui_visible

func _set_ui_visible(v: bool) -> void:
	_ui_visible = v
	visible = v
	if lbl != null:
		lbl.visible = v

func _set_maj_interval_frames(v: int) -> void:
	_maj_interval_frames = max(v, 1)

func _set_label_pos(v: Vector2) -> void:
	_label_pos = v
	if lbl != null:
		lbl.position = v

func _set_label_scale(v: Vector2) -> void:
	_label_scale = v
	if lbl != null:
		lbl.scale = v

func _set_label_z_index(v: int) -> void:
	_label_z_index = v
	if lbl != null:
		lbl.z_index = v

func _set_label_modulate(v: Color) -> void:
	_label_modulate = v
	if lbl != null:
		lbl.modulate = v

func _set_label_name(v: StringName) -> void:
	_label_name = v
	if is_inside_tree():
		_creer_label_si_besoin()
		_appliquer_style_label()
