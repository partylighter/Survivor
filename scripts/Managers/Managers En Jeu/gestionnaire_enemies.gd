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
@export var rayon_simulation: float = 1400.0
@export var rayon_disparition: float = 2000.0
@export var lod_update_interval_frames: int = 3

@export var loot_activation_radius: float = 900.0
@export var loot_budget_par_frame: int = 80

@export var budget_par_frame: int = 200
@export var max_spawn_par_frame: int = 15

@export var max_full_actifs: int = 30
@export var max_buffer_actifs: int = 60
@export var rayon_engage: float = 300.0

@export var vitesse_lointain: float = 40.0
@export var freq_lointain_frames: int = 6

@export var mode_vagues: bool = true
@export var interlude_s: float = 4.0
@export var vagues_infinies: bool = false
@export var croissance_taux: float = 1.1
@export var croissance_max: float = 1.1
@export var croissance_total: float = 1.1

@export var durees_vagues: PackedFloat32Array = []
@export var taux_vagues: PackedFloat32Array = []
@export var max_vivants_vagues: PackedInt32Array = []
@export var total_max_vagues: PackedInt32Array = []
@export var cibles_tues_vagues: PackedInt32Array = []
@export var poids_par_vague: Array[PackedFloat32Array] = []

@export var loot_manager: GestionnaireLootDrops

@export_group("Horde visuelle")
@export var horde_visuelle_path: NodePath
@export var horde_faux_voulus: int = 0
@export var portee_arme_px: float = 500.0
@export var marge_securite_horde_px: float = 200.0
@export var maj_horde_frames: int = 10
@onready var horde_visuelle: HordeFausse = get_node_or_null(horde_visuelle_path) as HordeFausse
var _frame_horde: int = 0

@export_group("Foule")
@export var foule_actif: bool = true
@export var foule_rayon_px: float = 18.0 # distance (en pixels) en dessous de laquelle deux ennemis commencent à se repousser.
@export var foule_force_px_s: float = 180.0 # intensité maximale de la poussée ajoutée (vitesse de répulsion).
@export var foule_taille_cellule_px: float = 40.0 # aille des cases de la grille spatiale utilisée pour trouver les voisins rapidement (perf)
@export var foule_budget_par_frame: int = 140 # nombre max d’ennemis traités par frame pour la foule (limite de coût CPU)
@export var foule_update_interval_frames: int = 1
@export var foule_max_voisins_par_ennemi: int = 24
@export var foule_d2_min: float = 1.0

var _foule_grille: Dictionary = {}
var _foule_liste: Array[Enemy] = []
var _foule_curseur: int = 0
var _foule_frame: int = 0

var ennemis: Array[Node2D] = []
var pools: Array = []

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

var tour_budget: int = 0
var _lod_frame: int = 0

var ennemis_tues_total: int = 0
var temps_total_s: float = 0.0
var vagues_terminees: int = 0

func _ready() -> void:
	hasard.seed = graine

	if not is_instance_valid(joueur):
		push_warning("chemin_joueur invalide")
	if scenes_ennemis.is_empty():
		push_warning("scenes_ennemis est vide")
	if not poids_types.is_empty() and poids_types.size() != scenes_ennemis.size():
		push_warning("poids_types et scenes_ennemis de tailles différentes")
	if not (rayon_disparition > rayon_simulation and rayon_simulation >= rayon_spawn_max and rayon_spawn_max >= rayon_spawn_min):
		push_warning("invariants de rayon invalides")

	_init_pools()

	if mode_vagues and _nb_vagues() > 0:
		_demarrer_vague(0)

	if horde_visuelle != null:
		var anneau_min: float = max(rayon_spawn_max, portee_arme_px + marge_securite_horde_px)
		var anneau_max: float = max(rayon_disparition, anneau_min + 200.0)
		horde_visuelle.configurer_anneau(anneau_min, anneau_max)
		horde_visuelle.set_nombre_actif(horde_faux_voulus)

func _process(dt: float) -> void:
	temps_total_s += dt

	if mode_vagues and _nb_vagues() > 0:
		if en_interlude:
			timer_interlude -= dt
			if timer_interlude <= 0.0:
				_prochaine_vague()
		else:
			_tick_vague(dt)
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

	if foule_actif:
		_foule_frame = (_foule_frame + 1) % max(foule_update_interval_frames, 1)
		if _foule_frame == 0:
			_reconstruire_grille_foule()
		_maj_foule()

	if horde_visuelle != null:
		_frame_horde += 1
		if _frame_horde >= max(maj_horde_frames, 1):
			_frame_horde = 0
			horde_visuelle.set_nombre_actif(horde_faux_voulus)

	_maj_budget()

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

	var max_tot2: int = _total_max_courant()
	if max_tot2 >= 0 and total_spawn_vague >= max_tot2 and vivants_vague == 0:
		_finir_vague()

func _finir_vague() -> void:
	en_interlude = true
	timer_interlude = interlude_s
	vagues_terminees += 1

func _prochaine_vague() -> void:
	en_interlude = false
	if i_vague + 1 < _nb_vagues():
		_demarrer_vague(i_vague + 1)
	else:
		if vagues_infinies:
			cycle_vagues += 1
			_demarrer_vague(0)
		else:
			en_interlude = true
			timer_interlude = 999999.0

func _demarrer_vague(index: int) -> void:
	i_vague = index
	t_vague = 0.0
	acc_vague = 0.0
	vivants_vague = 0
	total_spawn_vague = 0
	tues_vague = 0

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

func _rendre_a_pool(e: Node2D) -> void:
	if not is_instance_valid(e):
		return
	if not e.has_meta("type_idx"):
		e.queue_free()
		return

	var type_idx: int = int(e.get_meta("type_idx"))

	_activer_ennemi(e, false)
	e.hide()

	if e.get_parent() == self:
		remove_child(e)

	if type_idx >= 0 and type_idx < pools.size():
		if is_instance_valid(e):
			pools[type_idx].append(e)
	else:
		e.queue_free()

func _creer_ennemi() -> void:
	if scenes_ennemis.is_empty():
		return
	var idx: int = _choisir_type()
	_creer_ennemi_index(idx, rayon_spawn_min, rayon_spawn_max)

func _creer_ennemi_index(idx: int, rmin: float, rmax: float) -> Node2D:
	if scenes_ennemis.is_empty() or not is_instance_valid(joueur):
		return null

	idx = clamp(idx, 0, scenes_ennemis.size() - 1)

	var e: Node2D = _prendre_depuis_pool(idx)
	if e == null:
		e = scenes_ennemis[idx].instantiate() as Node2D
		if e == null:
			return null
		e.set_meta("type_idx", idx)
	else:
		if e.has_method("reactiver_apres_pool"):
			e.call("reactiver_apres_pool")

	e.global_position = _position_spawn_rayon(rmin, rmax)

	if e.get_parent() != self:
		add_child(e)

	_activer_ennemi(e, true)
	e.show()

	if not ennemis.has(e):
		ennemis.append(e)

	e.set_meta("vague_id", i_vague if mode_vagues else -1)
	e.set_meta("lod_mode", -1)

	if e.has_signal("mort"):
		var cb: Callable = Callable(self, "_sur_mort").bind(e)
		if not e.is_connected("mort", cb):
			e.connect("mort", cb)

	emit_signal("ennemi_cree", e)
	return e

func _sur_mort(e: Node2D) -> void:
	ennemis_tues_total += 1

	if loot_manager != null and is_instance_valid(joueur):
		var prog: float = get_indice_progression_loot()
		loot_manager.generer_loot_pour_ennemi(e, hasard, joueur, prog)

	ennemis.erase(e)

	if e.has_meta("vague_id"):
		var v: Variant = e.get_meta("vague_id")
		if typeof(v) == TYPE_INT and int(v) == i_vague:
			vivants_vague = max(0, vivants_vague - 1)
			tues_vague += 1

	_rendre_a_pool(e)
	emit_signal("ennemi_tue", e)

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
			if not e.has_meta("sl"):
				e.set_meta("sl", co.collision_layer)
			if not e.has_meta("sm"):
				e.set_meta("sm", co.collision_mask)
			co.collision_layer = 0
			co.collision_mask = 0

func _tick_lointain(e: Node2D) -> void:
	if not is_instance_valid(joueur):
		return
	var dir: Vector2 = (joueur.global_position - e.global_position).normalized()
	e.global_position += dir * vitesse_lointain * 0.1

func _cmp_proches(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("d2", 0.0)) < float(b.get("d2", 0.0))

func _get_lod_mode(e: Node2D) -> int:
	if not e.has_meta("lod_mode"):
		return -1
	var v: Variant = e.get_meta("lod_mode")
	return int(v) if typeof(v) == TYPE_INT else -1

func _set_lod_mode_si_change(e: Node2D, mode: int) -> void:
	var cur: int = _get_lod_mode(e)
	if cur == mode:
		return
	e.set_meta("lod_mode", mode)
	_set_enemy_mode(e, mode)

func _set_enemy_mode(e: Node2D, mode: int) -> void:
	if not is_instance_valid(e):
		return

	match mode:
		0:
			_activer_ennemi(e, true)
			var en: Enemy = e as Enemy
			if en != null:
				en.set_combat_state(true, true)
		1:
			_activer_ennemi(e, true)
			var en2: Enemy = e as Enemy
			if en2 != null:
				en2.set_combat_state(false, true)
		2:
			_activer_ennemi(e, false)
			var en3: Enemy = e as Enemy
			if en3 != null:
				en3.set_combat_state(false, false)

func _appliquer_lod() -> void:
	if ennemis.is_empty() or not is_instance_valid(joueur):
		return

	var r2_sim: float = rayon_simulation * rayon_simulation
	var r2_engage: float = rayon_engage * rayon_engage

	var proches: Array[Dictionary] = []
	var reste: Array[Dictionary] = []

	for e: Node2D in ennemis:
		if not is_instance_valid(e):
			continue

		var d2: float = joueur.global_position.distance_squared_to(e.global_position)

		if d2 > r2_sim:
			_set_lod_mode_si_change(e, 2)
			continue

		if d2 <= r2_engage:
			proches.append({"d2": d2, "e": e})
		else:
			reste.append({"d2": d2, "e": e})

	proches.sort_custom(Callable(self, "_cmp_proches"))
	reste.sort_custom(Callable(self, "_cmp_proches"))

	var full_limit: int = max(max_full_actifs, 0)
	var buffer_limit: int = max(max_buffer_actifs, full_limit)

	var used: int = 0

	for item_p: Dictionary in proches:
		var ep: Node2D = item_p.get("e") as Node2D
		if ep == null:
			continue
		var mode_p: int = 2
		if used < full_limit:
			mode_p = 0
		elif used < buffer_limit:
			mode_p = 1
		_set_lod_mode_si_change(ep, mode_p)
		used += 1

	for item_r: Dictionary in reste:
		var er: Node2D = item_r.get("e") as Node2D
		if er == null:
			continue
		var mode_r: int = 2
		if used < full_limit:
			mode_r = 0
		elif used < buffer_limit:
			mode_r = 1
		_set_lod_mode_si_change(er, mode_r)
		used += 1

func _maj_budget() -> void:
	if ennemis.is_empty() or not is_instance_valid(joueur):
		return

	var r2_sim: float = rayon_simulation * rayon_simulation
	var r2_disp: float = rayon_disparition * rayon_disparition

	var quota: int = min(budget_par_frame, ennemis.size())
	if quota <= 0:
		return

	var start: int = int((int(tour_budget) * quota) % max(1, ennemis.size()))
	var fait: int = 0
	var idx: int = start

	while fait < quota and ennemis.size() > 0:
		if idx >= ennemis.size():
			idx = 0
		if _eval_ou_supprime(idx, r2_sim, r2_disp):
			pass
		else:
			idx += 1
		fait += 1

	tour_budget += 1


func _eval_ou_supprime(i: int, r2_sim: float, r2_disp: float) -> bool:
	if i < 0 or i >= ennemis.size() or not is_instance_valid(joueur):
		return false

	var e: Node2D = ennemis[i]
	if not is_instance_valid(e):
		var last_invalid: int = ennemis.size() - 1
		ennemis[i] = ennemis[last_invalid]
		ennemis.remove_at(last_invalid)
		return true

	var d2: float = joueur.global_position.distance_squared_to(e.global_position)

	if d2 <= r2_sim:
		return false

	if d2 <= r2_disp:
		_activer_ennemi(e, false)
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

	var last: int = ennemis.size() - 1
	ennemis[i] = ennemis[last]
	ennemis.remove_at(last)

	_rendre_a_pool(e)
	emit_signal("ennemi_retire", e)

	return true

func _position_spawn_rayon(rmin: float, rmax: float) -> Vector2:
	var a: float = hasard.randf_range(0.0, TAU)
	var r: float = hasard.randf_range(rmin, rmax)
	return joueur.global_position + Vector2(cos(a), sin(a)) * r

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
	return max(0.0, base)

func _taux_courant() -> float:
	var base: float = apparitions_par_sec
	if i_vague < taux_vagues.size():
		base = taux_vagues[i_vague]
	return base * pow(croissance_taux, cycle_vagues)

func _max_vivants_courant() -> int:
	var base: int = -1
	if i_vague < max_vivants_vagues.size():
		base = max_vivants_vagues[i_vague]
	if base < 0:
		return -1
	var val: int = int(round(float(base) * pow(croissance_max, cycle_vagues)))
	return max(0, val)

func _total_max_courant() -> int:
	var base: int = -1
	if i_vague < total_max_vagues.size():
		base = total_max_vagues[i_vague]
	if base < 0:
		return -1
	var val: int = int(round(float(base) * pow(croissance_total, cycle_vagues)))
	return max(0, val)

func _cible_tues_courante() -> int:
	if i_vague < cibles_tues_vagues.size():
		return cibles_tues_vagues[i_vague]
	return -1

func get_indice_progression_loot() -> float:
	var indice: float = 0.0
	if mode_vagues:
		indice += float(vagues_terminees)
	else:
		indice += temps_total_s / 60.0
		indice += float(ennemis_tues_total) / 50.0
	return max(indice, 0.0)

func _cellule_foule(pos: Vector2) -> Vector2i:
	var s: float = max(foule_taille_cellule_px, 1.0)
	return Vector2i(int(floor(pos.x / s)), int(floor(pos.y / s)))

func _reconstruire_grille_foule() -> void:
	_foule_grille.clear()
	_foule_liste.clear()

	for n: Node2D in ennemis:
		var e: Enemy = n as Enemy
		if e == null:
			continue
		if not is_instance_valid(e):
			continue
		if not e.is_physics_processing():
			continue

		_foule_liste.append(e)

		var key: Vector2i = _cellule_foule(e.global_position)
		var arr: Array = _foule_grille.get(key, []) as Array
		if arr.is_empty():
			_foule_grille[key] = arr
		arr.append(e)

	if _foule_curseur >= _foule_liste.size():
		_foule_curseur = 0

func _maj_foule() -> void:
	if _foule_liste.is_empty():
		return

	var r: float = max(foule_rayon_px, 0.0)
	if r <= 0.0:
		return
	var r2: float = r * r

	var n_total: int = _foule_liste.size()
	var kmax: int = n_total if foule_budget_par_frame <= 0 else int(min(foule_budget_par_frame, n_total))
	if kmax <= 0:
		return

	var max_voisins: int = max(foule_max_voisins_par_ennemi, 0)
	var d2_min: float = max(foule_d2_min, 0.0001)
	var force: float = max(foule_force_px_s, 0.0)
	if force <= 0.0:
		return

	for _k: int in range(kmax):
		if n_total <= 0:
			return
		if _foule_curseur >= n_total:
			_foule_curseur = 0

		var e: Enemy = _foule_liste[_foule_curseur]
		_foule_curseur += 1
		if not is_instance_valid(e):
			continue

		var pos: Vector2 = e.global_position
		var cell: Vector2i = _cellule_foule(pos)

		var push: Vector2 = Vector2.ZERO
		var voisins_pris: int = 0
		var voisins_proches: int = 0

		for dx: int in range(-1, 2):
			if max_voisins > 0 and voisins_pris >= max_voisins:
				break
			for dy: int in range(-1, 2):
				if max_voisins > 0 and voisins_pris >= max_voisins:
					break

				var key: Vector2i = cell + Vector2i(dx, dy)
				var arr: Array = _foule_grille.get(key, []) as Array
				if arr.is_empty():
					continue

				for obj: Variant in arr:
					if max_voisins > 0 and voisins_pris >= max_voisins:
						break

					var other: Enemy = obj as Enemy
					if other == null or other == e or not is_instance_valid(other):
						continue

					var d: Vector2 = pos - other.global_position
					var d2: float = d.length_squared()
					if d2 >= r2:
						continue

					if d == Vector2.ZERO:
						d = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
						if d.length_squared() < 0.0001:
							d = Vector2.RIGHT
						d = d.normalized()
						d2 = d2_min
					else:
						d2 = max(d2, d2_min)

					voisins_pris += 1
					voisins_proches += 1

					var inv_len: float = 1.0 / sqrt(d2)
					var w: float = (r2 - d2) / r2
					push += d * inv_len * w

		if push == Vector2.ZERO and voisins_proches > 0:
			var rr2: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			if rr2.length_squared() >= 0.0001:
				push = rr2.normalized() * float(voisins_proches)

		if push != Vector2.ZERO:
			var vpush: Vector2 = (push * force).limit_length(force)
			e.set_poussee_foule(vpush)
