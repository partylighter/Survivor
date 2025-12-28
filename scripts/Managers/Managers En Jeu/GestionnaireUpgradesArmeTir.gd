extends Node
class_name GestionnaireUpgradesArmeTir

enum Mode { SET, ADD, MUL }

@export var actif: bool = true
@export var debug_upgrades: bool = false

@export_group("Mode")
@export var mode_arme: Mode = Mode.SET
@export var mode_projectile: Mode = Mode.SET

@export_group("ArmeBase - Modifs")
@export var mod_degats: bool = false
@export var degats: int = 10

@export var mod_duree_active_s: bool = false
@export var duree_active_s: float = 0.12

@export var mod_cooldown_s: bool = false
@export var cooldown_s: float = 0.3

@export var mod_recul_force: bool = false
@export var recul_force: float = 200.0

@export_group("ArmeTir - Modifs")
@export var mod_nb_balles: bool = false
@export var nb_balles: int = 1

@export var mod_dispersion_deg: bool = false
@export var dispersion_deg: float = 0.0

@export var mod_hitscan: bool = false
@export var hitscan: bool = false

@export var mod_tir_max_par_frame: bool = false
@export var tir_max_par_frame: int = 20

@export var mod_portee_hitscan_px: bool = false
@export var portee_hitscan_px: float = 2000.0

@export var mod_mask_tir: bool = false
@export var mask_tir: int = 0

@export_group("Projectile - Modifs")
@export var mod_duree_vie_s: bool = false
@export var duree_vie_s: float = 1.5

@export var mod_vitesse_px_s: bool = false
@export var vitesse_px_s: float = 1400.0

@export var mod_collision_mask: bool = false
@export var collision_mask: int = 0

@export var mod_marge_raycast_px: bool = false
@export var marge_raycast_px: float = 1.0

@export var mod_largeur_zone_scane: bool = false
@export var largeur_zone_scane: float = 0.0

@export var mod_nombre_de_rayon_dans_zone_scane: bool = false
@export var nombre_de_rayon_dans_zone_scane: int = 2

@export var mod_contacts_avant_destruction: bool = false
@export var contacts_avant_destruction: int = 1

@export var mod_ignorer_meme_cible: bool = false
@export var ignorer_meme_cible: bool = true

var _props_ok: Dictionary = {}
var _base_vals: Dictionary = {}

const _ARME_PROPS: Array[StringName] = [
	&"degats", &"duree_active_s", &"cooldown_s", &"recul_force",
	&"nb_balles", &"dispersion_deg", &"hitscan", &"tir_max_par_frame",
	&"portee_hitscan_px", &"mask_tir"
]

const _PROJ_PROPS: Array[StringName] = [
	&"duree_vie_s", &"vitesse_px_s", &"collision_mask", &"marge_raycast_px",
	&"largeur_zone_scane", &"nombre_de_rayon_dans_zone_scane",
	&"contacts_avant_destruction", &"ignorer_meme_cible"
]

func _ready() -> void:
	add_to_group("upg_arme_tir")

func re_appliquer() -> void:
	var armes := get_tree().get_nodes_in_group("armes_tir")
	if armes.is_empty():
		return
	var arme := armes[0] as ArmeTir
	if arme == null or not is_instance_valid(arme):
		return
	appliquer_sur_arme(arme)
	appliquer_sur_projectiles_pool_et_actifs(arme)

func appliquer_sur_arme(arme: ArmeTir) -> void:
	if arme == null:
		return
	_ensure_ok_and_base(arme, _ARME_PROPS)

	if not actif:
		_restaurer_obj(arme, _ARME_PROPS)
		return

	_apply_num(arme, &"degats", mod_degats, degats, mode_arme)
	_apply_num(arme, &"duree_active_s", mod_duree_active_s, duree_active_s, mode_arme)
	_apply_num(arme, &"cooldown_s", mod_cooldown_s, cooldown_s, mode_arme)
	_apply_num(arme, &"recul_force", mod_recul_force, recul_force, mode_arme)

	_apply_num(arme, &"nb_balles", mod_nb_balles, nb_balles, mode_arme)
	_apply_num(arme, &"dispersion_deg", mod_dispersion_deg, dispersion_deg, mode_arme)
	_apply_set(arme, &"hitscan", mod_hitscan, hitscan)
	_apply_num(arme, &"tir_max_par_frame", mod_tir_max_par_frame, tir_max_par_frame, mode_arme)
	_apply_num(arme, &"portee_hitscan_px", mod_portee_hitscan_px, portee_hitscan_px, mode_arme)
	_apply_set(arme, &"mask_tir", mod_mask_tir, mask_tir)

func appliquer_sur_projectile(p: Projectile) -> void:
	if p == null:
		return
	_ensure_ok_and_base(p, _PROJ_PROPS)

	if not actif:
		_restaurer_obj(p, _PROJ_PROPS)
		return

	_apply_num(p, &"duree_vie_s", mod_duree_vie_s, duree_vie_s, mode_projectile)
	_apply_num(p, &"vitesse_px_s", mod_vitesse_px_s, vitesse_px_s, mode_projectile)
	_apply_set(p, &"collision_mask", mod_collision_mask, collision_mask)
	_apply_num(p, &"marge_raycast_px", mod_marge_raycast_px, marge_raycast_px, mode_projectile)
	_apply_num(p, &"largeur_zone_scane", mod_largeur_zone_scane, largeur_zone_scane, mode_projectile)
	_apply_set(p, &"nombre_de_rayon_dans_zone_scane", mod_nombre_de_rayon_dans_zone_scane, nombre_de_rayon_dans_zone_scane)
	_apply_num(p, &"contacts_avant_destruction", mod_contacts_avant_destruction, contacts_avant_destruction, mode_projectile)
	_apply_set(p, &"ignorer_meme_cible", mod_ignorer_meme_cible, ignorer_meme_cible)

func appliquer_sur_projectiles_pool_et_actifs(arme: ArmeTir) -> void:
	if arme == null:
		return

	var pool = arme.get("_pool")
	if pool is Array:
		for obj in pool:
			var p: Projectile = obj as Projectile
			if p != null and is_instance_valid(p):
				appliquer_sur_projectile(p)

	var root = arme.get("_root_proj")
	var root_node: Node = root as Node
	if root_node != null and is_instance_valid(root_node):
		for c in root_node.get_children():
			var pp: Projectile = c as Projectile
			if pp != null and is_instance_valid(pp):
				appliquer_sur_projectile(pp)

func _ensure_ok_and_base(o: Object, props: Array[StringName]) -> void:
	var id := o.get_instance_id()

	if not _props_ok.has(id):
		var ok := {}
		for d in o.get_property_list():
			ok[StringName(d.name)] = true
		_props_ok[id] = ok

	if not _base_vals.has(id):
		var base := {}
		for p in props:
			if _props_ok[id].has(p):
				base[p] = o.get(p)
		_base_vals[id] = base

func _base(o: Object, prop: StringName):
	var id := o.get_instance_id()
	if not _base_vals.has(id):
		return o.get(prop)
	var b: Dictionary = _base_vals[id]
	if not b.has(prop):
		return o.get(prop)
	return b[prop]

func _has(o: Object, prop: StringName) -> bool:
	var id := o.get_instance_id()
	return _props_ok.has(id) and _props_ok[id].has(prop)

func _restaurer_obj(o: Object, props: Array[StringName]) -> void:
	for p in props:
		if _has(o, p):
			var v = _base(o, p)
			o.set(p, v)
			_dbg(o, p, v, "BASE")

func _apply_set(o: Object, prop: StringName, enabled: bool, v) -> void:
	if not _has(o, prop):
		return
	var out = v if enabled else _base(o, prop)
	o.set(prop, out)
	_dbg(o, prop, out, "SET" if enabled else "BASE")

func _apply_num(o: Object, prop: StringName, enabled: bool, v, mode: int) -> void:
	if not _has(o, prop):
		return

	var b = _base(o, prop)

	if not enabled:
		o.set(prop, b)
		_dbg(o, prop, b, "BASE")
		return

	if mode == Mode.SET:
		o.set(prop, v)
		_dbg(o, prop, v, "SET")
		return

	var tb := typeof(b)
	var tv := typeof(v)
	if tb in [TYPE_INT, TYPE_FLOAT] and tv in [TYPE_INT, TYPE_FLOAT]:
		if mode == Mode.ADD:
			var out_add = b + v
			o.set(prop, out_add)
			_dbg(o, prop, out_add, "ADD")
		elif mode == Mode.MUL:
			var out_mul = b * v
			o.set(prop, out_mul)
			_dbg(o, prop, out_mul, "MUL")
		else:
			o.set(prop, v)
			_dbg(o, prop, v, "SET")
	else:
		o.set(prop, v)
		_dbg(o, prop, v, "SET")

func _dbg(o: Object, prop: StringName, v, tag: String) -> void:
	if debug_upgrades:
		print("[Upgrades] ", o.get_class(), "#", o.get_instance_id(), " ", tag, " ", prop, "=", v)
