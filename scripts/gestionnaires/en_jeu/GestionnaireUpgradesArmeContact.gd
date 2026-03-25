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

var _stacks: Dictionary = {}
var _upg_by_slot: Dictionary = {}

var _props_cache: Dictionary = {}
var _base_arme: Dictionary = {}
var _base_hitbox: Dictionary = {}

var _cfg_base: Dictionary = {}

func _ready() -> void:
	add_to_group("upg_arme_contact")
	_cfg_base = {
		&"degats": degats,
		&"duree_active_s": duree_active_s,
		&"cooldown_s": cooldown_s,
		&"recul_force": recul_force,
		&"hitbox_collision_mask": hitbox_collision_mask,
		&"hitbox_collision_layer": hitbox_collision_layer,
		&"hitbox_disabled": hitbox_disabled,
		&"hitbox_monitoring": hitbox_monitoring
	}

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
	if o == null:
		return false

	var id := o.get_instance_id()
	if not _props_cache.has(id):
		var props := {}
		for d in o.get_property_list():
			props[StringName(d.name)] = true
		_props_cache[id] = props

	return _props_cache[id].has(prop)

func ajouter_upgrade_par_id(id_item: StringName, quantite: int = 1) -> void:
	if not actif:
		return

	var reg := get_tree().get_first_node_in_group("upgrade_registry") as UpgradeRegistry
	var upg := reg.get_upgrade(id_item) if reg != null else null
	if upg == null:
		if debug_upgrades:
			print("[UpgContact] upgrade introuvable: ", String(id_item))
		return

	var q := maxi(1, quantite)

	var cur := int(_stacks.get(id_item, 0))
	var max_s := int(upg.max_stacks)
	var next := cur + q
	if max_s > 0:
		next = mini(next, max_s)

	_stacks[id_item] = next
	_upg_by_slot[upg.slot] = { "id": id_item, "q": next }

	re_appliquer()
	for a in get_tree().get_nodes_in_group("armes_contact"):
		if a is ArmeContact and is_instance_valid(a):
			appliquer_sur(a)

	if debug_upgrades:
		print("[UpgContact] add id=", String(id_item), " q=", q, " stacks=", next, " max=", max_s, " prop=", String(upg.prop), " mode=", int(upg.mode))

func re_appliquer() -> void:
	if not actif:
		return

	mod_degats = false
	mod_duree_active_s = false
	mod_cooldown_s = false
	mod_recul_force = false

	mod_hitbox_collision_mask = false
	mod_hitbox_collision_layer = false
	mod_hitbox_disabled = false
	mod_hitbox_monitoring = false

	degats = int(_cfg_base[&"degats"])
	duree_active_s = float(_cfg_base[&"duree_active_s"])
	cooldown_s = float(_cfg_base[&"cooldown_s"])
	recul_force = float(_cfg_base[&"recul_force"])

	hitbox_collision_mask = int(_cfg_base[&"hitbox_collision_mask"])
	hitbox_collision_layer = int(_cfg_base[&"hitbox_collision_layer"])
	hitbox_disabled = bool(_cfg_base[&"hitbox_disabled"])
	hitbox_monitoring = bool(_cfg_base[&"hitbox_monitoring"])

	var reg := get_tree().get_first_node_in_group("upgrade_registry") as UpgradeRegistry
	if reg == null:
		return

	for id_item in _stacks.keys():
		var idsn: StringName = id_item as StringName
		var stacks: int = int(_stacks[id_item])

		var upg := reg.get_upgrade(idsn)
		if upg == null:
			continue
		if upg.cible != UpgradeData.Target.ARME:
			continue

		if upg.prop == &"degats":
			mod_degats = true
		elif upg.prop == &"duree_active_s":
			mod_duree_active_s = true
		elif upg.prop == &"cooldown_s":
			mod_cooldown_s = true
		elif upg.prop == &"recul_force":
			mod_recul_force = true
		elif upg.prop == &"hitbox_collision_mask":
			mod_hitbox_collision_mask = true
		elif upg.prop == &"hitbox_collision_layer":
			mod_hitbox_collision_layer = true
		elif upg.prop == &"hitbox_disabled":
			mod_hitbox_disabled = true
		elif upg.prop == &"hitbox_monitoring":
			mod_hitbox_monitoring = true
		if upg.cible != UpgradeData.Target.ARME: 
			continue
		if upg.slot != &"contact":
			continue

		upg.apply_to(self, stacks)

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
