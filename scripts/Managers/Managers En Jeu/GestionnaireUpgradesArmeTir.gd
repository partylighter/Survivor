extends Node
class_name GestionnaireUpgradesArmeTir

# =====================================================================================
# BUT
# =====================================================================================
# Ce node reçoit des IDs d’items d’upgrade (depuis LaboloMenu),
# transforme ces IDs en "UpgradeData" (via UpgradeRegistry),
# stocke ces upgrades (par slot + stacks),
# puis ré-applique les effets sur :
#   - l’arme de tir courante (groupe "armes_tir")
#   - tous les projectiles (pool + projectiles actifs de l’arme)
#
# CONNEXIONS / DÉPENDANCES
# - LaboloMenu.gd :
#     appelle upg_tir_ref.ajouter_upgrade_par_id(id_item, q)
# - UpgradeRegistry.gd :
#     fournit get_upgrade(id_item) -> UpgradeData
# - UpgradeData.gd (Resource) :
#     contient cible (ARME/PROJECTILE), prop, mode, valeur, slot, max_stacks
#     et apply_to(obj, stacks) qui applique la modif sur une propriété existante.
# - ArmeTir :
#     doit être dans le groupe "armes_tir"
#     et exposer _pool (Array) + _root_proj (Node) comme dans ton code existant
# - Projectile :
#     objets sur lesquels on applique les upgrades cible PROJECTILE
#
# IMPORTANT
# - Ce script garde TON système "manuel" (exports mod_... + valeurs) intact.
# - MAIS : si un UpgradeData est trouvé dans UpgradeRegistry, on applique la voie "registry"
#   (donc plus besoin d’ajouter des if sid == ... pour chaque upgrade).
# - Les upgrades sont stockés par slot:
#     un slot = un emplacement logique (ex: "canon", "munitions", "chargeur")
#     si tu mets un nouvel upgrade dans le même slot, il remplace l’ancien.
# =====================================================================================

enum Mode { SET, ADD, MUL }

@export var actif: bool = true
@export var debug_upgrades: bool = false

@export_group("Mode (manuel)")
@export var mode_arme: Mode = Mode.SET
@export var mode_projectile: Mode = Mode.SET

@export_group("ArmeBase - Modifs (manuel)")
@export var mod_degats: bool = false
@export var degats: int = 10

@export var mod_duree_active_s: bool = false
@export var duree_active_s: float = 0.12

@export var mod_cooldown_s: bool = false
@export var cooldown_s: float = 0.3

@export var mod_recul_force: bool = false
@export var recul_force: float = 200.0

@export_group("ArmeTir - Modifs (manuel)")
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

@export_group("Projectile - Modifs (manuel)")
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

# -------------------------------------------------------------------------------------
# Registry (data-driven)
# -------------------------------------------------------------------------------------
# Option A : tu mets le NodePath dans l’inspecteur
# Option B : tu mets UpgradeRegistry dans le groupe "upgrade_registry"
@export_node_path("UpgradeRegistry") var chemin_registry: NodePath

var _registry: UpgradeRegistry = null

# Stockage "par slot"
# slot -> { "id": StringName, "stacks": int }
var _upg_by_slot: Dictionary = {}

# Stockage "brut" par id (utile si tu veux afficher ton inventaire/stacks ou debug)
# id -> int
var _upg_stacks: Dictionary = {}

# -------------------------------------------------------------------------------------
# Cache de propriétés + valeurs de base (ton système existant)
# -------------------------------------------------------------------------------------
var _props_ok: Dictionary = {}   # instance_id -> { prop_name: true }
var _base_vals: Dictionary = {}  # instance_id -> { prop_name: value }

# IMPORTANT FIX :
# Tant qu’aucune upgrade n’a été appliquée sur une instance, on autorise la "base" à se refresh
# (utile si l’arme/proj initialisent leurs stats après _ready() / deferred / await).
# Dès qu’on applique une upgrade, on LOCK la base, sinon tu captures 0 et ADD/MUL ressemblent à SET.
var _base_locked: Dictionary = {} # instance_id -> bool

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
	# IMPORTANT : LaboloMenu cherche ce node via ce groupe :
	# GROUPE_UPG_TIR = "upg_arme_tir"
	add_to_group("upg_arme_tir")
	_ensure_registry() # évite _registry=null au premier drop

# =====================================================================================
# 0) BASE LOCK (FIX)
# =====================================================================================
func _is_base_locked(o: Object) -> bool:
	return bool(_base_locked.get(o.get_instance_id(), false))

func _lock_base(o: Object) -> void:
	_base_locked[o.get_instance_id()] = true

func _unlock_base(o: Object) -> void:
	_base_locked.erase(o.get_instance_id())

# =====================================================================================
# 1) RÉCUPÉRER LE REGISTRY
# =====================================================================================
func _ensure_registry() -> void:
	# Si on a déjà une ref valide -> rien à faire
	if _registry != null and is_instance_valid(_registry):
		return

	# Option A (prioritaire) : tu fournis un NodePath dans l’inspecteur
	# Exemple : chemin_registry = "../UpgradeRegistry"
	if chemin_registry != NodePath():
		_registry = get_node_or_null(chemin_registry) as UpgradeRegistry

	# Option B : fallback via groupe (si tu n’as pas renseigné le NodePath)
	# Il faut que le node UpgradeRegistry soit dans le groupe "upgrade_registry"
	if _registry == null and get_tree() != null:
		_registry = get_tree().get_first_node_in_group(&"upgrade_registry") as UpgradeRegistry

	# Si on l’a trouvé : on force un rebuild pour être sûr que la map _map est à jour
	# (utile si tu modifies la liste "upgrades" à runtime)
	if _registry != null:
		_registry.rebuild_now()
		return

	# Debug si introuvable
	if debug_upgrades:
		print("[Upgrades] registry introuvable (set chemin_registry OU group upgrade_registry)")

func re_appliquer_sur_arme(arme: ArmeTir) -> void:
	if arme == null or not is_instance_valid(arme):
		return

	# 1) applique ton système manuel
	appliquer_sur_arme(arme)

	# 2) reset base des props registry ciblées ARME (évite empilement / drift)
	_restaurer_registry_props_sur_obj(arme, int(UpgradeData.Target.ARME))

	# 3) applique les upgrades registry ARME
	_ensure_registry()
	if _registry != null:
		for slot in _upg_by_slot.keys():
			var entry: Dictionary = _upg_by_slot[slot]
			var uid: StringName = entry.get("id", &"") as StringName
			var stacks: int = int(entry.get("stacks", 1))
			if uid == &"" or stacks <= 0:
				continue

			var upg := _registry.get_upgrade(uid)
			if upg == null:
				continue
			if int(upg.cible) == int(UpgradeData.Target.ARME):
				upg.apply_to(arme, stacks)

	# 4) applique aussi la couche projectile (pool + actifs)
	appliquer_sur_projectiles_pool_et_actifs(arme)

# =====================================================================================
# 2) POINT D’ENTRÉE : appelé par LaboloMenu quand tu drop un item upgrade
# =====================================================================================
func ajouter_upgrade_par_id(id_item: StringName, q: int) -> void:
	# "q" vient de LaboloMenu (pris=1 par défaut)
	var add_q := maxi(q, 0)
	if add_q <= 0:
		return

	var sid := StringName(String(id_item))

	# On garde une trace de stacks par id (utile pour UI / debug / stats)
	_upg_stacks[sid] = int(_upg_stacks.get(sid, 0)) + add_q

	# -------------------------------------------------------------------------
	# VOIE 1 (recommandée) : registry data-driven
	# -------------------------------------------------------------------------
	_ensure_registry()
	if _registry != null:
		var upg := _registry.get_upgrade(sid)
		if upg != null:
			var slot: StringName = upg.slot if upg.slot != &"" else &"default"

			var entry: Dictionary = _upg_by_slot.get(slot, {})
			var cur_id: StringName = entry.get("id", &"") as StringName
			var cur_stacks: int = int(entry.get("stacks", 0))

			# Remplacement si un autre upgrade est déjà dans ce slot
			if cur_id != sid:
				cur_id = sid
				cur_stacks = 0

			# Clamp stacks
			var maxs: int = maxi(int(upg.max_stacks), 1)
			cur_stacks = mini(cur_stacks + add_q, maxs)

			entry["id"] = cur_id
			entry["stacks"] = cur_stacks
			_upg_by_slot[slot] = entry

			# IMPORTANT FIX :
			# On LOCK la base de l’arme (et plus tard des projectiles quand ils seront touchés).
			# Sinon ta base peut être capturée "trop tôt" (0), et ADD/MUL ressemblent à SET.
			var armes := get_tree().get_nodes_in_group("armes_tir")
			if not armes.is_empty():
				var arme := armes[0] as ArmeTir
				if arme != null and is_instance_valid(arme):
					_lock_base(arme)

			if debug_upgrades:
				print("[Upgrades] slot=", String(slot), " id=", String(cur_id), " stacks=", cur_stacks)

			re_appliquer()
			return

	# -------------------------------------------------------------------------
	# VOIE 2 (fallback) : ton système "manuel" via if sid == ...
	# -------------------------------------------------------------------------
	if sid == &"upg_test_vitesse":
		mode_projectile = Mode.ADD
		mod_vitesse_px_s = true
		vitesse_px_s = 100.0 * float(int(_upg_stacks[sid])) # +100 par stack
	elif sid == &"upgrade_test_degats":
		mode_arme = Mode.ADD
		mod_degats = true
		degats = 2 * int(_upg_stacks[sid]) # +2 par stack
	else:
		if debug_upgrades:
			print("[Upgrades] id inconnu (pas dans registry)=", String(sid))

	# IMPORTANT FIX :
	# Même en fallback, on lock la base de l’arme dès qu’on applique une upgrade.
	var armes2 := get_tree().get_nodes_in_group("armes_tir")
	if not armes2.is_empty():
		var arme2 := armes2[0] as ArmeTir
		if arme2 != null and is_instance_valid(arme2):
			_lock_base(arme2)

	re_appliquer()

# =====================================================================================
# 3) RÉ-APPLICATION GLOBALE
# =====================================================================================
func re_appliquer() -> void:
	# On prend la première arme de tir trouvée (comme ton code existant)
	var armes := get_tree().get_nodes_in_group("armes_tir")
	if armes.is_empty():
		return

	var arme := armes[0] as ArmeTir
	if arme == null or not is_instance_valid(arme):
		return

	# 3.0 Si désactivé -> on restaure tout propre (manuel + props registry) et on sort.
	if not actif:
		_ensure_ok_and_base(arme, _ARME_PROPS)
		_restaurer_obj(arme, _ARME_PROPS)
		_restaurer_registry_props_sur_obj(arme, int(UpgradeData.Target.ARME))
		appliquer_sur_projectiles_pool_et_actifs(arme) # lui gère aussi actif=false
		return

	# 3.1 Applique le système manuel (exports mod_... etc.)
	appliquer_sur_arme(arme)

	# 3.2 IMPORTANT FIX :
	# On remet d'abord les propriétés ciblées par le registry à leur BASE,
	# sinon apply_to() s'applique sur une valeur déjà modifiée et tu peux te retrouver
	# avec (a) des valeurs qui "driftent" à chaque re_appliquer ou (b) des ADD/MUL qui s'empilent.
	_restaurer_registry_props_sur_obj(arme, int(UpgradeData.Target.ARME))

	# 3.3 Applique les upgrades registry qui ciblent l'arme
	_ensure_registry()
	if _registry != null:
		for slot in _upg_by_slot.keys():
			var entry: Dictionary = _upg_by_slot[slot]
			var uid: StringName = entry.get("id", &"") as StringName
			var stacks: int = int(entry.get("stacks", 1))
			if uid == &"" or stacks <= 0:
				continue

			var upg := _registry.get_upgrade(uid)
			if upg == null:
				continue

			if int(upg.cible) == int(UpgradeData.Target.ARME):
				upg.apply_to(arme, stacks)

	# 3.4 Applique sur tous les projectiles (pool + actifs)
	appliquer_sur_projectiles_pool_et_actifs(arme)

# =====================================================================================
# 4) APPLICATION SUR ARME (manuel)
# =====================================================================================
func appliquer_sur_arme(arme: ArmeTir) -> void:
	if arme == null:
		return

	_ensure_ok_and_base(arme, _ARME_PROPS)

	# Si désactivé -> reset à la base (manuel)
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

# =====================================================================================
# 5) APPLICATION SUR PROJECTILE (manuel)
# =====================================================================================
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

# =====================================================================================
# 6) POOL + PROJECTILES ACTIFS
# =====================================================================================
func appliquer_sur_projectiles_pool_et_actifs(arme: ArmeTir) -> void:
	if arme == null:
		return

	_ensure_registry()

	# Prépare la liste des upgrades registry qui ciblent PROJECTILE
	var proj_upgs: Array[Dictionary] = []
	if _registry != null:
		for slot in _upg_by_slot.keys():
			var entry: Dictionary = _upg_by_slot[slot]
			var uid: StringName = entry.get("id", &"") as StringName
			var stacks: int = int(entry.get("stacks", 1))
			if uid == &"" or stacks <= 0:
				continue
			var upg := _registry.get_upgrade(uid)
			if upg != null and int(upg.cible) == int(UpgradeData.Target.PROJECTILE):
				proj_upgs.append({"upg": upg, "stacks": stacks})

	# 6.1 Pool (projectiles recyclés)
	var pool = arme.get("_pool")
	if pool is Array:
		for obj in pool:
			var p: Projectile = obj as Projectile
			if p != null and is_instance_valid(p):
				# IMPORTANT FIX :
				# Dès qu’on touche un projectile, on LOCK sa base pour éviter refresh après modifs.
				_lock_base(p)

				# D’abord ton système manuel
				appliquer_sur_projectile(p)

				# IMPORTANT FIX : reset des props registry projetile à la BASE avant apply_to()
				_restaurer_registry_props_sur_instance(p, proj_upgs)

				# Ensuite la couche registry
				for d in proj_upgs:
					(d["upg"] as UpgradeData).apply_to(p, int(d["stacks"]))

	# 6.2 Projectiles actifs sous _root_proj
	var root = arme.get("_root_proj")
	var root_node: Node = root as Node
	if root_node != null and is_instance_valid(root_node):
		for c in root_node.get_children():
			var pp: Projectile = c as Projectile
			if pp != null and is_instance_valid(pp):
				_lock_base(pp)
				appliquer_sur_projectile(pp)
				_restaurer_registry_props_sur_instance(pp, proj_upgs)
				for d in proj_upgs:
					(d["upg"] as UpgradeData).apply_to(pp, int(d["stacks"]))

# =====================================================================================
# 6bis) RESTAURATION BASE POUR LES PROPS CIBLÉES PAR LE REGISTRY (FIX)
# =====================================================================================
func _restaurer_registry_props_sur_obj(obj: Object, cible: int) -> void:
	_ensure_registry()
	if _registry == null or obj == null or not is_instance_valid(obj):
		return

	# Pour chaque upgrade actif (par slot), on remet la prop à sa valeur de base avant apply_to()
	for slot in _upg_by_slot.keys():
		var entry: Dictionary = _upg_by_slot[slot]
		var uid: StringName = entry.get("id", &"") as StringName
		var stacks: int = int(entry.get("stacks", 1))
		if uid == &"" or stacks <= 0:
			continue

		var upg := _registry.get_upgrade(uid)
		if upg == null:
			continue
		if int(upg.cible) != cible:
			continue
		if upg.prop == &"":
			continue

		# On s'assure que la prop est dans le cache et qu'on a une base pour elle,
		# même si elle n’est pas dans _ARME_PROPS/_PROJ_PROPS.
		_ensure_prop_base(obj, upg.prop)

		if _has(obj, upg.prop):
			obj.set(upg.prop, _base(obj, upg.prop))

func _restaurer_registry_props_sur_instance(obj: Object, proj_upgs: Array[Dictionary]) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	for d in proj_upgs:
		var upg: UpgradeData = d["upg"] as UpgradeData
		if upg == null:
			continue
		if upg.prop == &"":
			continue
		_ensure_prop_base(obj, upg.prop)
		if _has(obj, upg.prop):
			obj.set(upg.prop, _base(obj, upg.prop))

func _ensure_prop_base(o: Object, prop: StringName) -> void:
	var id := o.get_instance_id()

	if not _props_ok.has(id):
		var ok := {}
		for d in o.get_property_list():
			ok[StringName(d.name)] = true
		_props_ok[id] = ok

	if not _base_vals.has(id):
		_base_vals[id] = {}

	var base: Dictionary = _base_vals[id]

	# IMPORTANT FIX :
	# Tant que la base n’est pas lock, on refresh la base (prop peut avoir été initialisée après).
	if not _is_base_locked(o):
		if _props_ok[id].has(prop):
			base[prop] = o.get(prop)
			_base_vals[id] = base
		return

	if not base.has(prop) and _props_ok[id].has(prop):
		base[prop] = o.get(prop)
		_base_vals[id] = base

# =====================================================================================
# 7) UTILITAIRES (cache base vals / props existantes) - ton code existant
# =====================================================================================
func _ensure_ok_and_base(o: Object, props: Array[StringName]) -> void:
	var id := o.get_instance_id()

	if not _props_ok.has(id):
		var ok := {}
		for d in o.get_property_list():
			ok[StringName(d.name)] = true
		_props_ok[id] = ok

	if not _base_vals.has(id):
		_base_vals[id] = {}

	var base: Dictionary = _base_vals[id]

	# IMPORTANT FIX :
	# Tant que pas lock, on refresh les bases (si arme/proj set ses vraies stats après).
	if not _is_base_locked(o):
		for p in props:
			if _props_ok[id].has(p):
				base[p] = o.get(p)
		_base_vals[id] = base
		return

	# Si lock : on ne remplace pas les bases déjà capturées, on complète juste si manque.
	for p in props:
		if _props_ok[id].has(p) and not base.has(p):
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
