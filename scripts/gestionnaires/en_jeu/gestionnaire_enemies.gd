extends Node2D
class_name GestionnaireEnnemis

signal ennemi_cree(e)
signal ennemi_tue(e)
signal ennemi_retire(e)
signal limite_atteinte()

@export var chemin_joueur: NodePath
@onready var joueur: Node2D = get_node_or_null(chemin_joueur) as Node2D

@export var scenes_ennemis: Array[PackedScene] = []
@export var poids_types: PackedFloat32Array = []
@export var graine: int = 1

@export var max_ennemis: int = 500
@export var apparitions_par_sec: float = 5.0

@export var rayon_spawn_min: float = 600.0
@export var rayon_spawn_max: float = 900.0
@export var demi_hauteur_bande_spawn: float = 250.0

@export var rayon_disparition: float = 2000.0
@export var lod_update_interval_frames: int = 3

@export var budget_par_frame: int = 200
@export var max_spawn_par_frame: int = 15

@export var max_full_actifs: int = 30
@export var max_buffer_actifs: int = 60

@export var vitesse_lointain: float = 40.0
@export var freq_lointain_frames: int = 6

@export_group("LOD écran")
@export var marge_visible_ecran_px: float = 120.0
@export var marge_buffer_ecran_px: float = 350.0

@export_group("Vagues")
@export var mode_vagues: bool = true
@export var interlude_s: float = 4.0
@export var vagues_infinies: bool = false
@export var croissance_taux: float = 1.1
@export var croissance_max: float = 1.1
@export var croissance_total: float = 1.1
@export var duree_vague_defaut_infinie: float = 30.0

@export var durees_vagues: PackedFloat32Array = []
@export var taux_vagues: PackedFloat32Array = []
@export var max_vivants_vagues: PackedInt32Array = []
@export var total_max_vagues: PackedInt32Array = []
@export var cibles_tues_vagues: PackedInt32Array = []
@export var poids_par_vague: Array[PackedFloat32Array] = []

@export var loot_manager: GestionnaireLootDrops

## Optionnel — si assigné, active le spawn par zone (remplace le spawn continu
## non-vague). Laisser vide pour conserver le comportement existant.
@export var gestionnaire_zones: GestionnaireZones = null

var ennemis: Array[Node2D] = []
# Index de zone au dernier spawn — permet de détecter un changement de zone
# et de remettre l'accumulateur à zéro pour éviter un burst de spawn.
var _zone_idx_spawn: int = -1
var _ennemis_set: Dictionary = {}
var pools: Array = []

var _lod_modes: Dictionary = {}

var _rect_visible_cache: Rect2 = Rect2()
var _rect_buffer_cache: Rect2 = Rect2()
var _nb_vagues_cache: int = 0

var _r2_disp: float = 0.0

var _pow_taux: float  = 1.0
var _pow_max: float   = 1.0
var _pow_total: float = 1.0

var accumulateur: float = 0.0
var hasard: RandomNumberGenerator = RandomNumberGenerator.new()

var i_vague: int = -1
var cycle_vagues: int = 0
var t_vague: float = 0.0
var en_interlude: bool = false
var timer_interlude: float = 0.0
var acc_vague: float = 0.0
var vivants_vague: int = 0
var total_spawn_vague: int = 0
var tues_vague: int = 0

# [CORRECTIF BUG 5] Flag dédié pour ne plus utiliser timer_interlude=999999 comme
# signal de fin — on arrête proprement la boucle de vagues.
var _toutes_vagues_terminees: bool = false

var tour_budget: int = 0
var _lod_frame: int = 0

var ennemis_tues_total: int = 0
var temps_total_s: float = 0.0
var vagues_terminees: int = 0
var joueur_mort: bool = false

# ===========================================================================
# Initialisation
# ===========================================================================

func _ready() -> void:
	add_to_group("gestion_ennemis")

	hasard.seed = graine

	_r2_disp = rayon_disparition * rayon_disparition

	if not is_instance_valid(joueur):
		push_warning("chemin_joueur invalide")
	if scenes_ennemis.is_empty():
		push_warning("scenes_ennemis est vide")
	if not poids_types.is_empty() and poids_types.size() != scenes_ennemis.size():
		push_warning("poids_types et scenes_ennemis de tailles différentes")
	if not (rayon_disparition >= rayon_spawn_max and rayon_spawn_max >= rayon_spawn_min):
		push_warning("invariants de rayon invalides")

	_init_pools()

	_nb_vagues_cache = _nb_vagues()
	if mode_vagues and _nb_vagues_cache > 0:
		_demarrer_vague(0)

	if gestionnaire_zones != null:
		gestionnaire_zones.zone_changee.connect(_sur_zone_changee)

	_rect_visible_cache = _get_rect_camera_monde(marge_visible_ecran_px)
	_rect_buffer_cache  = _get_rect_camera_monde(marge_buffer_ecran_px)


# ===========================================================================
# Boucle principale
# ===========================================================================

func _process(dt: float) -> void:
	temps_total_s += dt
	if joueur_mort:
		return

	_nb_vagues_cache    = _nb_vagues()
	_rect_visible_cache = _get_rect_camera_monde(marge_visible_ecran_px)
	_rect_buffer_cache  = _get_rect_camera_monde(marge_buffer_ecran_px)

	if mode_vagues and _nb_vagues_cache > 0:
		# [CORRECTIF BUG 5] On ne traite plus les vagues si elles sont finies.
		if not _toutes_vagues_terminees:
			if en_interlude:
				timer_interlude -= dt
				if timer_interlude <= 0.0:
					_prochaine_vague()
			else:
				_tick_vague(dt)
	else:
		if gestionnaire_zones != null:
			_tick_spawn_zone(dt)
		else:
			accumulateur += apparitions_par_sec * dt
			while accumulateur >= 1.0:
				accumulateur -= 1.0
				if ennemis.size() >= max_ennemis:
					emit_signal("limite_atteinte")
					break
				_creer_ennemi()

	if _lod_frame == 0:
		_appliquer_lod()
	_lod_frame = (_lod_frame + 1) % max(lod_update_interval_frames, 1)

	_maj_budget()

# ===========================================================================
# Joueur mort
# ===========================================================================

func set_player_dead(v: bool) -> void:
	joueur_mort = v
	if joueur_mort:
		for n: Node2D in ennemis:
			var e := n as Enemy
			if e != null and is_instance_valid(e):
				e.set_combat_state(false, false)

# ===========================================================================
# Vagues
# ===========================================================================

func _tick_vague(dt: float) -> void:
	t_vague += dt
	var taux: float = _taux_courant()
	acc_vague += taux * dt

	var crees_ce_frame: int = 0
	while acc_vague >= 1.0 and crees_ce_frame < max_spawn_par_frame:
		if ennemis.size() >= max_ennemis:
			break

		var max_viv: int = _max_vivants_courant()
		if max_viv >= 0 and vivants_vague >= max_viv:
			break

		var max_tot: int = _total_max_courant()
		if max_tot >= 0 and total_spawn_vague >= max_tot:
			break

		acc_vague -= 1.0

		var idx: int = _choisir_type_vague()
		var e: Node2D = _creer_ennemi_index(idx, rayon_spawn_min, rayon_spawn_max)
		if e == null:
			break

		e.set_meta("vague_id", i_vague)
		vivants_vague += 1
		total_spawn_vague += 1
		crees_ce_frame += 1

	var cible: int = _cible_tues_courante()
	if cible >= 0 and tues_vague >= cible:
		_finir_vague()
		return

	var duree: float = _duree_courante()
	if duree > 0.0 and t_vague >= duree:
		_finir_vague()
		return

	# [CORRECTIF BUG 4] La condition précédente vérifiait max_tot2 >= 0 ET
	# vivants_vague == 0, mais ignorait le cas où max_tot est infini (-1) avec
	# tous les ennemis morts. On sépare les deux logiques :
	# - Si total limité : fin quand quota atteint ET plus personne en vie.
	# - Si total illimité (cible=-1, duree=0) : pas de fin automatique par épuisement.
	var max_tot2: int = _total_max_courant()
	if max_tot2 >= 0 and total_spawn_vague >= max_tot2 and vivants_vague <= 0:
		_finir_vague()

func _finir_vague() -> void:
	en_interlude = true
	timer_interlude = interlude_s
	vagues_terminees += 1

func _prochaine_vague() -> void:
	en_interlude = false
	if i_vague + 1 < _nb_vagues_cache:
		_demarrer_vague(i_vague + 1)
	else:
		if vagues_infinies:
			cycle_vagues += 1
			_demarrer_vague(_nb_vagues_cache - 1)
		else:
			# [CORRECTIF BUG 5] On pose le flag de fin au lieu de boucler
			# indéfiniment avec timer_interlude = 999999 qui redéclenchait
			# _prochaine_vague() à chaque frame une fois le timer écoulé.
			_toutes_vagues_terminees = true

# ===========================================================================
# Pool
# ===========================================================================

func _demarrer_vague(index: int) -> void:
	i_vague = index
	t_vague = 0.0
	acc_vague = 0.0
	vivants_vague = 0
	total_spawn_vague = 0
	tues_vague = 0
	_pow_taux  = pow(croissance_taux,  cycle_vagues)
	_pow_max   = pow(croissance_max,   cycle_vagues)
	_pow_total = pow(croissance_total, cycle_vagues)

func _init_pools() -> void:
	pools.clear()
	for _i: int in range(scenes_ennemis.size()):
		pools.append([])

func _prendre_depuis_pool(type_idx: int) -> Node2D:
	if type_idx < 0 or type_idx >= pools.size():
		return null
	var pile: Array = pools[type_idx]
	while not pile.is_empty():
		var e: Node2D = pile.pop_back() as Node2D
		if is_instance_valid(e):
			return e
	return null

# ===========================================================================
# Création ennemis
# ===========================================================================

func spawn_force(type_idx: int, pos: Vector2, vague_id: int = -1, metas: Dictionary = {}) -> Node2D:
	return _creer_ennemi_index_pos(type_idx, pos, vague_id, metas)

func _creer_ennemi_index_pos(idx: int, pos: Vector2, vague_id: int, metas: Dictionary) -> Node2D:
	if scenes_ennemis.is_empty() or not is_instance_valid(joueur):
		return null

	idx = clamp(idx, 0, scenes_ennemis.size() - 1)

	var e: Node2D = _prendre_depuis_pool(idx)
	var est_nouveau: bool = (e == null)
	if est_nouveau:
		e = scenes_ennemis[idx].instantiate() as Node2D
		if e == null:
			return null
		e.set_meta("type_idx", idx)

	e.global_position = pos
	if e.has_method("reactiver_apres_pool"):
		e.call("reactiver_apres_pool")

	if e.get_parent() != self:
		add_child(e)

	_activer_ennemi(e, true)

	if not _ennemis_set.has(e):
		ennemis.append(e)
		_ennemis_set[e] = true

	e.set_meta("vague_id", vague_id)
	_lod_modes[e] = -1

	for k in metas.keys():
		e.set_meta(k, metas[k])

	if est_nouveau:
		_connecter_signaux(e)

	# [CORRECTIF BUG 6] spawn_force n'incrémentait pas les compteurs de vague,
	# ce qui faussait les conditions de fin (max_vivants, total_max).
	# On met à jour uniquement si le vague_id correspond à la vague en cours.
	if mode_vagues and vague_id == i_vague:
		vivants_vague += 1
		total_spawn_vague += 1

	_appliquer_lod_immediat_sur_ennemi(e)

	emit_signal("ennemi_cree", e)
	return e

func _creer_ennemi() -> void:
	if scenes_ennemis.is_empty():
		return
	var idx: int = _choisir_type()
	_creer_ennemi_index(idx, rayon_spawn_min, rayon_spawn_max)

# ---------------------------------------------------------------------------
# Spawn par zone
# ---------------------------------------------------------------------------

func _tick_spawn_zone(dt: float) -> void:
	if not is_instance_valid(joueur):
		return

	var zone_idx: int          = gestionnaire_zones.index_zone_en(joueur.global_position.x)
	var zone:     ZoneDefinition = gestionnaire_zones.zone_active

	# Changement de zone → reset accumulateur pour éviter un burst.
	if zone_idx != _zone_idx_spawn:
		_zone_idx_spawn = zone_idx
		accumulateur    = 0.0

	if zone == null:
		return

	var cap: int = min(zone.max_ennemis_zone, max_ennemis)
	if ennemis.size() >= cap:
		return

	accumulateur += zone.apparitions_par_sec * dt
	while accumulateur >= 1.0:
		accumulateur -= 1.0
		if ennemis.size() >= cap:
			break
		var idx: int = _choisir_type_pour_zone(zone)
		_creer_ennemi_index(idx, rayon_spawn_min, rayon_spawn_max)

func _choisir_type_pour_zone(zone: ZoneDefinition) -> int:
	if zone == null:
		return _choisir_type()

	if not zone.scenes_ennemis.is_empty():
		return _choisir_type_depuis_scenes_zone(zone)

	return _choisir_type_depuis_poids(zone.poids)

func _choisir_type_depuis_scenes_zone(zone: ZoneDefinition) -> int:
	if zone == null or zone.scenes_ennemis.is_empty():
		return _choisir_type()

	var scene_locale_idx: int = 0
	if zone.poids.size() == zone.scenes_ennemis.size():
		scene_locale_idx = _choisir_index_depuis_poids(zone.poids)
	else:
		scene_locale_idx = hasard.randi_range(0, zone.scenes_ennemis.size() - 1)

	var scene: PackedScene = zone.scenes_ennemis[scene_locale_idx]
	var idx_global: int = _trouver_index_scene_globale(scene)
	if idx_global >= 0:
		return idx_global

	push_warning("GestionnaireEnnemis: la scene de zone '%s' n'existe pas dans scenes_ennemis." % [scene.resource_path])
	return _choisir_type()

func _choisir_type_depuis_poids(poids: PackedFloat32Array) -> int:
	if poids.is_empty() or poids.size() != scenes_ennemis.size():
		return _choisir_type()
	return _choisir_index_depuis_poids(poids)

func _choisir_index_depuis_poids(poids: PackedFloat32Array) -> int:
	var total: float = 0.0
	for w: float in poids:
		total += w
	if total <= 0.0:
		return 0
	var x: float = hasard.randf() * total
	var s: float = 0.0
	for ii: int in range(poids.size()):
		s += poids[ii]
		if x <= s:
			return ii
	return 0

func _trouver_index_scene_globale(scene: PackedScene) -> int:
	if scene == null:
		return -1

	var idx_direct: int = scenes_ennemis.find(scene)
	if idx_direct >= 0:
		return idx_direct

	var path: String = scene.resource_path
	if path.is_empty():
		return -1

	for i: int in range(scenes_ennemis.size()):
		var scene_globale: PackedScene = scenes_ennemis[i]
		if scene_globale != null and scene_globale.resource_path == path:
			return i

	return -1

## Spawne une scène directement sans qu'elle soit pré-enregistrée dans
## scenes_ennemis. Utilisé pour les boss de zone.
## type_idx = -1 → l'ennemi sera queue_free'd au retour pool (pas poolé).
func spawn_scene_directe(scene: PackedScene, pos: Vector2) -> Node2D:
	if scene == null:
		return null
	var e: Node2D = scene.instantiate() as Node2D
	if e == null:
		return null
	e.set_meta("type_idx", -1)
	e.global_position = pos
	if e.has_method("reactiver_apres_pool"):
		e.call("reactiver_apres_pool")
	add_child(e)
	_activer_ennemi(e, true)
	ennemis.append(e)
	_ennemis_set[e] = true
	e.set_meta("vague_id", -1)
	_lod_modes[e] = -1
	_connecter_signaux(e)
	_appliquer_lod_immediat_sur_ennemi(e)
	emit_signal("ennemi_cree", e)
	return e

func _sur_zone_changee(_ancienne: ZoneDefinition, _nouvelle: ZoneDefinition) -> void:
	accumulateur    = 0.0
	_zone_idx_spawn = -1

## Retourne la liste des ennemis actifs (utilisé par le joueur pour les collisions).
func get_ennemis_actifs() -> Array:
	return ennemis

func _creer_ennemi_index(idx: int, rmin: float, rmax: float) -> Node2D:
	if scenes_ennemis.is_empty() or not is_instance_valid(joueur):
		return null

	idx = clamp(idx, 0, scenes_ennemis.size() - 1)

	var e: Node2D = _prendre_depuis_pool(idx)
	var est_nouveau: bool = (e == null)
	if est_nouveau:
		e = scenes_ennemis[idx].instantiate() as Node2D
		if e == null:
			return null
		e.set_meta("type_idx", idx)

	e.global_position = _position_spawn_rayon(rmin, rmax)

	if e.has_method("reactiver_apres_pool"):
		e.call("reactiver_apres_pool")

	if e.get_parent() != self:
		add_child(e)

	_activer_ennemi(e, true)

	if not _ennemis_set.has(e):
		ennemis.append(e)
		_ennemis_set[e] = true

	e.set_meta("vague_id", i_vague if mode_vagues else -1)
	_lod_modes[e] = -1

	if est_nouveau:
		_connecter_signaux(e)

	_appliquer_lod_immediat_sur_ennemi(e)

	emit_signal("ennemi_cree", e)
	return e

func _connecter_signaux(e: Node2D) -> void:
	if e.has_signal("mort"):
		e.connect("mort", _sur_mort.bind(e))
	if e.has_signal("pret_pour_pool"):
		e.connect("pret_pour_pool", _sur_pret_pour_pool.bind(e))

# ===========================================================================
# Retour pool
# ===========================================================================

func _rendre_a_pool(e: Node2D) -> void:
	if not is_instance_valid(e):
		return
	if not e.has_meta("type_idx"):
		e.queue_free()
		return

	var type_idx: int = int(e.get_meta("type_idx"))

	if e is Enemy:
		(e as Enemy).set_combat_state(false, false)
	_activer_ennemi(e, false)
	_lod_modes.erase(e)

	if e.get_parent() == self:
		remove_child(e)

	if type_idx >= 0 and type_idx < pools.size():
		if is_instance_valid(e):
			pools[type_idx].append(e)
	else:
		e.queue_free()

# ===========================================================================
# Callbacks mort / pool
# ===========================================================================

func _sur_mort(e: Node2D) -> void:
	ennemis_tues_total += 1

	var pos_mort: Vector2 = e.global_position
	var type_ennemi: int = -1
	if e is Enemy:
		type_ennemi = (e as Enemy).type_ennemi

	if loot_manager != null and is_instance_valid(loot_manager) and type_ennemi != -1:
		var prog: float = get_indice_progression_loot()
		loot_manager.demander_drops(type_ennemi, pos_mort, hasard, joueur, prog)

	var idx_mort: int = ennemis.find(e)
	if idx_mort >= 0:
		ennemis[idx_mort] = ennemis[ennemis.size() - 1]
		ennemis.remove_at(ennemis.size() - 1)
	_ennemis_set.erase(e)

	if e.has_meta("vague_id"):
		var v: Variant = e.get_meta("vague_id")
		if typeof(v) == TYPE_INT and int(v) == i_vague:
			vivants_vague = max(0, vivants_vague - 1)
			tues_vague += 1

	emit_signal("ennemi_tue", e)

func _sur_pret_pour_pool(e: Node2D) -> void:
	_rendre_a_pool(e)

# ===========================================================================
# Activation / désactivation
# ===========================================================================

func _activer_ennemi(e: Node2D, actif: bool) -> void:
	e.set_physics_process(actif)
	e.set_process(actif)

	if e is CollisionObject2D:
		var co: CollisionObject2D = e as CollisionObject2D
		if actif:
			if e.has_meta("sl"):
				co.collision_layer = int(e.get_meta("sl"))
			if e.has_meta("sm"):
				co.collision_mask = int(e.get_meta("sm"))
		else:
			# [CORRECTIF BUG 7] On ne sauvegarde les valeurs de collision que
			# si elles n'ont pas encore été sauvegardées (layer/mask non nuls),
			# pour éviter d'écraser les vraies valeurs lors d'une double désactivation.
			if not e.has_meta("sl") and co.collision_layer != 0:
				e.set_meta("sl", co.collision_layer)
			if not e.has_meta("sm") and co.collision_mask != 0:
				e.set_meta("sm", co.collision_mask)
			co.collision_layer = 0
			co.collision_mask = 0

# ===========================================================================
# Caméra / rect
# ===========================================================================

func _get_camera_active() -> Camera2D:
	return get_viewport().get_camera_2d()

func _get_rect_camera_monde(marge: float = 0.0) -> Rect2:
	var cam: Camera2D = _get_camera_active()
	if cam == null:
		return Rect2()

	var taille_viewport: Vector2 = get_viewport_rect().size
	var demi_taille: Vector2 = (taille_viewport * 0.5) * cam.zoom
	var centre: Vector2 = cam.get_screen_center_position()
	var pos: Vector2 = centre - demi_taille
	var taille: Vector2 = demi_taille * 2.0

	return Rect2(
		pos - Vector2(marge, marge),
		taille + Vector2(marge * 2.0, marge * 2.0)
	)

func _est_dans_rect(rect: Rect2, p: Vector2) -> bool:
	return (
		p.x >= rect.position.x
		and p.y >= rect.position.y
		and p.x <= rect.position.x + rect.size.x
		and p.y <= rect.position.y + rect.size.y
	)

# ===========================================================================
# LOD
# ===========================================================================

func _tick_lointain(e: Node2D) -> void:
	if not is_instance_valid(joueur):
		return
	var d2: float = joueur.global_position.distance_squared_to(e.global_position)
	# Ne repositionne que si vraiment trop loin, pas juste hors buffer
	if d2 < _r2_disp:
		return
	var dir: Vector2 = (joueur.global_position - e.global_position).normalized()
	e.global_position = e.global_position + dir * vitesse_lointain * 0.1

func _set_lod_mode_si_change(e: Node2D, mode: int) -> void:
	if _lod_modes.get(e, -1) == mode:
		return
	_lod_modes[e] = mode
	_set_enemy_mode(e, mode)

func _set_enemy_mode(e: Node2D, mode: int) -> void:
	if not is_instance_valid(e):
		return
	match mode:
		0:
			e.show()
			_activer_ennemi(e, true)
			var en: Enemy = e as Enemy
			if en != null:
				en.set_combat_state(true, true)
		1:
			e.hide()
			_activer_ennemi(e, false)
			var en2: Enemy = e as Enemy
			if en2 != null:
				en2.set_combat_state(false, false)
		2:
			e.hide()
			_activer_ennemi(e, false)
			var en3: Enemy = e as Enemy
			if en3 != null:
				en3.set_combat_state(false, false)

func _appliquer_lod_immediat_sur_ennemi(e: Node2D) -> void:
	if not is_instance_valid(e):
		return
	var d2: float = joueur.global_position.distance_squared_to(e.global_position)
	if d2 > _r2_disp:
		_set_lod_mode_si_change(e, 2)
		return
	_set_lod_mode_si_change(e, 1)

func _appliquer_lod() -> void:
	if ennemis.is_empty() or not is_instance_valid(joueur):
		return

	var pos_joueur: Vector2 = joueur.global_position
	var visibles_ecran: Array = []
	var hors_ecran: Array    = []

	for e: Node2D in ennemis:
		if not is_instance_valid(e):
			continue
		var d2: float = pos_joueur.distance_squared_to(e.global_position)
		if d2 > _r2_disp:
			_set_lod_mode_si_change(e, 2)
			continue
		if _est_dans_rect(_rect_visible_cache, e.global_position):
			visibles_ecran.append([e, d2])
		else:
			hors_ecran.append([e, d2])

	var max_lite: int = max(0, max_buffer_actifs - max_full_actifs)
	var count_full: int = 0
	var count_lite: int = 0

	for pair in visibles_ecran:
		var e: Node2D = pair[0]
		if count_full < max_full_actifs:
			_set_lod_mode_si_change(e, 0)
			count_full += 1
		else:
			var mode_actuel: int = _lod_modes.get(e, -1)
			if mode_actuel == 0:
				count_full += 1
			else:
				_set_lod_mode_si_change(e, 1)

	hors_ecran.sort_custom(func(a, b): return a[1] < b[1])

	for pair in hors_ecran:
		var e: Node2D = pair[0]
		if count_full < max_full_actifs:
			_set_lod_mode_si_change(e, 0)
			count_full += 1
		elif count_lite < max_lite:
			var mode_actuel: int = _lod_modes.get(e, -1)
			if mode_actuel == 0:
				count_full += 1
			else:
				_set_lod_mode_si_change(e, 1)
			count_lite += 1
		else:
			var mode_actuel: int = _lod_modes.get(e, -1)
			if mode_actuel == 0:
				count_full += 1
			else:
				_set_lod_mode_si_change(e, 2)
# ===========================================================================
# Budget / suppression hors portée
# ===========================================================================

func _maj_budget() -> void:
	if ennemis.is_empty() or not is_instance_valid(joueur):
		return

	# [CORRECTIF BUG 3] L'ancienne formule était :
	#   int((int(tour_budget) * quota) % max(1, ennemis.size()))
	# à cause de la priorité des opérateurs, le produit pouvait déborder avant
	# le modulo. L'intention est simplement de décaler le point de départ du
	# budget à chaque tour pour couvrir tous les ennemis équitablement.
	# On utilise directement tour_budget % size, ce qui est correct et lisible.
	var quota: int = min(budget_par_frame, ennemis.size())
	if quota <= 0:
		return

	var start: int = tour_budget % max(1, ennemis.size())
	var fait: int = 0
	var idx: int = start

	while fait < quota and ennemis.size() > 0:
		if idx >= ennemis.size():
			idx = 0
		# [CORRECTIF BUG 1] Quand _eval_ou_supprime retire un ennemi, l'ennemi
		# qui était au dernier index est placé à idx. Il ne faut PAS incrémenter
		# idx dans ce cas, sinon on saute l'ennemi déplacé.
		# L'ancienne logique incrémentait idx dans tous les cas.
		var supprime: bool = _eval_ou_supprime(idx)
		if not supprime:
			idx += 1
		fait += 1

	tour_budget += 1

func _eval_ou_supprime(i: int) -> bool:
	if i < 0 or i >= ennemis.size() or not is_instance_valid(joueur):
		return false

	var e: Node2D = ennemis[i]
	if not is_instance_valid(e):
		var last_invalid: int = ennemis.size() - 1
		ennemis[i] = ennemis[last_invalid]
		ennemis.remove_at(last_invalid)
		_ennemis_set.erase(e)
		return true

	var d2: float = joueur.global_position.distance_squared_to(e.global_position)

	if d2 <= _r2_disp:
		var mode_actuel: int = _lod_modes.get(e, -1)
		if mode_actuel != 0:
			if freq_lointain_frames > 0 and (tour_budget % freq_lointain_frames) == 0:
				_tick_lointain(e)
		return false

	var doit_decrementer: bool = false
	if e.has_meta("vague_id"):
		var v: Variant = e.get_meta("vague_id")
		if typeof(v) == TYPE_INT and int(v) == i_vague:
			doit_decrementer = true

	if doit_decrementer:
		vivants_vague = max(0, vivants_vague - 1)
		# Note : les ennemis hors portée ne sont PAS comptés dans tues_vague
		# (ils fuient, ils ne meurent pas). C'est le comportement voulu.

	var last: int = ennemis.size() - 1
	ennemis[i] = ennemis[last]
	ennemis.remove_at(last)
	_ennemis_set.erase(e)
	_lod_modes.erase(e)

	_rendre_a_pool(e)
	emit_signal("ennemi_retire", e)

	return true

# ===========================================================================
# Spawn position
# ===========================================================================
func _position_spawn_rayon(rmin: float, rmax: float) -> Vector2:
	var cote: float = -1.0 if hasard.randf() < 0.5 else 1.0
	var x: float = joueur.global_position.x + cote * hasard.randf_range(rmin, rmax)
	var y: float = joueur.global_position.y + hasard.randf_range(-demi_hauteur_bande_spawn, demi_hauteur_bande_spawn)
	return Vector2(x, y)
# ===========================================================================
# Sélection type ennemi
# ===========================================================================

func _choisir_type() -> int:
	if poids_types.is_empty() or poids_types.size() != scenes_ennemis.size():
		return 0

	var total: float = 0.0
	for w: float in poids_types:
		total += w
	if total <= 0.0:
		return 0

	var x: float = hasard.randf() * total
	var s: float = 0.0
	for ii: int in range(poids_types.size()):
		s += poids_types[ii]
		if x <= s:
			return ii
	return 0

func _choisir_type_vague() -> int:
	var p: PackedFloat32Array = _poids_courants()
	if p.is_empty() or p.size() != scenes_ennemis.size():
		return _choisir_type()

	var total: float = 0.0
	for w: float in p:
		total += w
	if total <= 0.0:
		return _choisir_type()

	var x: float = hasard.randf() * total
	var s: float = 0.0
	for ii: int in range(p.size()):
		s += p[ii]
		if x <= s:
			return ii
	return 0

func _poids_courants() -> PackedFloat32Array:
	if i_vague >= 0 and i_vague < poids_par_vague.size():
		var p: PackedFloat32Array = poids_par_vague[i_vague]
		if p.size() == scenes_ennemis.size():
			return p
	return poids_types

# ===========================================================================
# Paramètres vagues
# ===========================================================================

func _nb_vagues() -> int:
	return max(
		taux_vagues.size(),
		max(
			durees_vagues.size(),
			max(
				max_vivants_vagues.size(),
				max(total_max_vagues.size(), cibles_tues_vagues.size())
			)
		)
	)

func _duree_courante() -> float:
	var base: float = 0.0
	if i_vague < durees_vagues.size():
		base = durees_vagues[i_vague]
	base = max(0.0, base)

	if base > 0.0:
		return base

	var cible: int = _cible_tues_courante()
	var tot: int = _total_max_courant()
	if vagues_infinies and cible < 0 and tot < 0:
		return max(0.0, duree_vague_defaut_infinie)

	return 0.0

func _taux_courant() -> float:
	var base: float = apparitions_par_sec
	if i_vague < taux_vagues.size():
		base = taux_vagues[i_vague]
	return base * _pow_taux

func _max_vivants_courant() -> int:
	var base: int = -1
	if i_vague < max_vivants_vagues.size():
		base = max_vivants_vagues[i_vague]
	if base < 0:
		return -1
	return max(0, int(round(float(base) * _pow_max)))

func _total_max_courant() -> int:
	var base: int = -1
	if i_vague < total_max_vagues.size():
		base = total_max_vagues[i_vague]
	if base < 0:
		return -1
	return max(0, int(round(float(base) * _pow_total)))

func _cible_tues_courante() -> int:
	if i_vague < cibles_tues_vagues.size():
		return cibles_tues_vagues[i_vague]
	return -1

# ===========================================================================
# Progression loot
# ===========================================================================

func get_indice_progression_loot() -> float:
	var indice: float = 0.0
	if mode_vagues:
		indice += float(vagues_terminees)
	else:
		indice += temps_total_s / 60.0
		indice += float(ennemis_tues_total) / 50.0
	return max(indice, 0.0)
