extends Node
class_name GestionnaireUpgradesArmeContact

enum Mode { SET, ADD, MUL }

@export var actif: bool = true
@export var debug_upgrades: bool = false

@export_group("Mode")
@export var mode_arme: Mode = Mode.SET
@export var mode_hitbox: Mode = Mode.SET

@export_group("ArmeBase - Modifs")
@export var mod_degats: bool = false
@export var degats: int = 10
@export var mod_duree_active_s: bool = false
@export var duree_active_s: float = 0.12
@export var mod_cooldown_s: bool = false
@export var cooldown_s: float = 0.3
@export var mod_recul_force: bool = false
@export var recul_force: float = 200.0

@export_group("HitBoxContact - Modifs")
@export var mod_hitbox_collision_mask: bool = false
@export var hitbox_collision_mask: int = 0
@export var mod_hitbox_collision_layer: bool = false
@export var hitbox_collision_layer: int = 0
@export var mod_hitbox_disabled: bool = false
@export var hitbox_disabled: bool = false
@export var mod_hitbox_monitoring: bool = false
@export var hitbox_monitoring: bool = true

var _props_cache: Dictionary = {}
var _base_arme: Dictionary = {}
var _base_hitbox: Dictionary = {}

func _ready() -> void:
	add_to_group("upg_arme_contact")

func appliquer_sur(arme: ArmeContact) -> void:
	if not actif or arme == null:
		return
	if not is_instance_valid(arme):
		return

	_capture_base_if_needed(arme)
	_revert_to_base(arme)

	_ensure_props_cache(arme)
	_patch(arme, &"degats", mod_degats, degats, mode_arme)
	_patch(arme, &"duree_active_s", mod_duree_active_s, duree_active_s, mode_arme)
	_patch(arme, &"cooldown_s", mod_cooldown_s, cooldown_s, mode_arme)
	_patch(arme, &"recul_force", mod_recul_force, recul_force, mode_arme)

	var hb: HitBoxContact = arme.hitbox
	if hb == null or not is_instance_valid(hb):
		hb = arme.get_node_or_null(arme.chemin_hitbox) as HitBoxContact
		arme.hitbox = hb

	if hb != null and is_instance_valid(hb):
		_capture_hitbox_base_if_needed(hb)
		_revert_hitbox_to_base(hb)

		_ensure_props_cache(hb)

		if mod_hitbox_disabled and _has_prop(hb, &"disabled"):
			hb.set_deferred("disabled", hitbox_disabled)
			_dbg(hb, &"disabled", hitbox_disabled, "SET")

		if mod_hitbox_monitoring and _has_prop(hb, &"monitoring"):
			hb.set_deferred("monitoring", hitbox_monitoring)
			_dbg(hb, &"monitoring", hitbox_monitoring, "SET")

		_patch(hb, &"collision_mask", mod_hitbox_collision_mask, hitbox_collision_mask, mode_hitbox)
		_patch(hb, &"collision_layer", mod_hitbox_collision_layer, hitbox_collision_layer, mode_hitbox)

func _capture_base_if_needed(arme: ArmeContact) -> void:
	var id := arme.get_instance_id()
	if _base_arme.has(id):
		return
	_base_arme[id] = {
		&"degats": arme.degats,
		&"duree_active_s": arme.duree_active_s,
		&"cooldown_s": arme.cooldown_s,
		&"recul_force": arme.recul_force
	}

func _revert_to_base(arme: ArmeContact) -> void:
	var id := arme.get_instance_id()
	if not _base_arme.has(id):
		return
	var b: Dictionary = _base_arme[id]
	arme.degats = b[&"degats"]
	arme.duree_active_s = b[&"duree_active_s"]
	arme.cooldown_s = b[&"cooldown_s"]
	arme.recul_force = b[&"recul_force"]

func _capture_hitbox_base_if_needed(hb: HitBoxContact) -> void:
	var id := hb.get_instance_id()
	if _base_hitbox.has(id):
		return
	var d := {}
	if _has_prop(hb, &"collision_mask"):
		d[&"collision_mask"] = hb.get("collision_mask")
	if _has_prop(hb, &"collision_layer"):
		d[&"collision_layer"] = hb.get("collision_layer")
	if _has_prop(hb, &"disabled"):
		d[&"disabled"] = hb.get("disabled")
	if _has_prop(hb, &"monitoring"):
		d[&"monitoring"] = hb.get("monitoring")
	_base_hitbox[id] = d

func _revert_hitbox_to_base(hb: HitBoxContact) -> void:
	var id := hb.get_instance_id()
	if not _base_hitbox.has(id):
		return
	var b: Dictionary = _base_hitbox[id]
	for k in b.keys():
		if _has_prop(hb, k):
			hb.set(k, b[k])

func _ensure_props_cache(o: Object) -> void:
	var id := o.get_instance_id()
	if _props_cache.has(id):
		return
	var props := {}
	for d in o.get_property_list():
		props[StringName(d.name)] = true
	_props_cache[id] = props

func _has_prop(o: Object, prop: StringName) -> bool:
	var id := o.get_instance_id()
	if not _props_cache.has(id):
		return false
	return _props_cache[id].has(prop)

func _patch(o: Object, prop: StringName, enabled: bool, v, mode: int) -> void:
	if not enabled:
		return
	if not _has_prop(o, prop):
		return

	if mode == Mode.SET:
		o.set(prop, v)
		_dbg(o, prop, v, "SET")
		return

	var cur = o.get(prop)
	if typeof(cur) in [TYPE_INT, TYPE_FLOAT] and typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		if mode == Mode.ADD:
			o.set(prop, cur + v)
			_dbg(o, prop, cur + v, "ADD")
		elif mode == Mode.MUL:
			o.set(prop, cur * v)
			_dbg(o, prop, cur * v, "MUL")
	else:
		o.set(prop, v)
		_dbg(o, prop, v, "SET")

func _dbg(o: Object, prop: StringName, v, tag: String) -> void:
	if debug_upgrades:
		print("[UpgContact] ", o.get_class(), "#", o.get_instance_id(), " ", tag, " ", prop, "=", v)
