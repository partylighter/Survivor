extends Node2D
class_name GestionnaireEnnemis

signal ennemi_cree(e)
signal ennemi_tue(e)
signal ennemi_retire(e)
signal limite_atteinte()

@export var chemin_joueur: NodePath
@onready var joueur: Node2D = get_node(chemin_joueur)

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
var _loot_index: int = 0


@export var budget_par_frame: int = 200
@export var max_spawn_par_frame: int = 15

# anneau intérieur (IA active + move_and_slide + push) 
@export var max_full_actifs: int = 30
# anneau tampon (visible, collisions gardées, mais IA coupée)
@export var max_buffer_actifs: int = 60
# anneau combat corps-à-corps
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

@export var scene_loot: PackedScene
@export var debug_loot: bool = false

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



func _process(dt: float) -> void:
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

	# LOD pas à chaque frame
	if _lod_frame == 0:
		_appliquer_lod()
	_lod_frame = (_lod_frame + 1) % lod_update_interval_frames

	_maj_budget()
	_maj_loots()

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
	for i in range(scenes_ennemis.size()):
		pools.append([])

func _prendre_depuis_pool(type_idx: int) -> Node2D:
	if type_idx < 0 or type_idx >= pools.size():
		return null
	var pile: Array = pools[type_idx]
	while not pile.is_empty():
		var e: Node2D = pile.pop_back()
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
	if scenes_ennemis.is_empty():
		return null

	idx = clamp(idx, 0, scenes_ennemis.size() - 1)

	var e: Node2D = _prendre_depuis_pool(idx)
	if e == null:
		e = scenes_ennemis[idx].instantiate() as Node2D
		e.set_meta("type_idx", idx)
	else:
		if e.has_method("reactiver_apres_pool"):
			e.reactiver_apres_pool()

	e.global_position = _position_spawn_rayon(rmin, rmax)

	if e.get_parent() != self:
		add_child(e)

	_activer_ennemi(e, true)
	e.show()

	if not ennemis.has(e):
		ennemis.append(e)

	e.set_meta("vague_id", i_vague if mode_vagues else -1)

	if e.has_signal("mort"):
		var callable := Callable(self, "_sur_mort").bind(e)
		if not e.is_connected("mort", callable):
			e.connect("mort", callable)

	emit_signal("ennemi_cree", e)
	return e

func _sur_mort(e: Node2D) -> void:
	call_deferred("_generer_loot_pour_ennemi", e)

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
		if actif:
			if e.has_meta("sl"):
				e.collision_layer = e.get_meta("sl")
			if e.has_meta("sm"):
				e.collision_mask = e.get_meta("sm")
		else:
			if not e.has_meta("sl"):
				e.set_meta("sl", e.collision_layer)
			if not e.has_meta("sm"):
				e.set_meta("sm", e.collision_mask)
			e.collision_layer = 0
			e.collision_mask = 0

func _tick_lointain(e: Node2D) -> void:
	var dir: Vector2 = (joueur.global_position - e.global_position).normalized()
	e.global_position += dir * vitesse_lointain * 0.1

func _cmp_proches(a, b) -> bool:
	return a["d2"] < b["d2"]

# applique 3 niveaux:
# 0 = noyau (IA on, move_and_slide on)
# 1 = tampon (IA off mais corps encore solide/visible)
# 2 = gel (IA off + collisions coupées)
func _set_enemy_mode(e: Node2D, mode: int) -> void:
	if not is_instance_valid(e):
		return

	match mode:
		0:
			_activer_ennemi(e, true)
			if e is Enemy:
				(e as Enemy).set_combat_state(true, true)
		1:
			_activer_ennemi(e, true)
			if e is Enemy:
				(e as Enemy).set_combat_state(false, true)
		2:
			_activer_ennemi(e, false)
			if e is Enemy:
				(e as Enemy).set_combat_state(false, false)

func _appliquer_lod() -> void:
	if ennemis.is_empty():
		return

	var r2_sim: float = rayon_simulation * rayon_simulation
	var r2_engage: float = rayon_engage * rayon_engage

	var engages: Array = []   # <= rayon_engage
	var reste: Array = []     # > rayon_engage mais encore dans rayon_simulation

	for e in ennemis:
		if not is_instance_valid(e):
			continue
		var d2: float = joueur.global_position.distance_squared_to(e.global_position)
		if d2 > r2_sim:
			continue

		if d2 <= r2_engage:
			engages.append(e)
		else:
			reste.append({"d2": d2, "e": e})

	# 1) proches collés au joueur: toujours full actif
	for e_close in engages:
		_set_enemy_mode(e_close, 0) # IA on, move_and_slide on

	# 2) rangs derrière: triés par distance puis découpés en full / buffer / gel
	if reste.is_empty():
		return

	reste.sort_custom(Callable(self, "_cmp_proches"))  # _cmp_proches lit ["d2"]

	var idx := 0
	for item in reste:
		var e2: Node2D = item["e"]

		if idx < max_full_actifs:
			_set_enemy_mode(e2, 0)   # IA on
		elif idx < max_buffer_actifs:
			_set_enemy_mode(e2, 1)   # IA off, corps solide
		else:
			_set_enemy_mode(e2, 2)   # gel total

		idx += 1

func _maj_budget() -> void:
	
	if ennemis.is_empty():
		return

	var r2_sim: float = rayon_simulation * rayon_simulation
	var r2_disp: float = rayon_disparition * rayon_disparition

	var quota: int = min(budget_par_frame, ennemis.size())
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


func _maj_loots() -> void:
	if not is_instance_valid(joueur):
		return

	var loots := get_tree().get_nodes_in_group("loots")
	if loots.is_empty():
		return

	var quota = min(loot_budget_par_frame, loots.size())
	if quota <= 0:
		return

	var r2 := loot_activation_radius * loot_activation_radius
	var start := _loot_index % loots.size()
	var i := start
	var done := 0

	while done < quota:
		var loot := loots[i] as Loot
		if is_instance_valid(loot):
			var d2 := joueur.global_position.distance_squared_to(loot.global_position)
			var actif := d2 <= r2
			loot.set_active(actif)

		i += 1
		if i >= loots.size():
			i = 0

		done += 1

	_loot_index = i

func _eval_ou_supprime(i: int, r2_sim: float, r2_disp: float) -> bool:
	if i < 0 or i >= ennemis.size():
		return false

	var e: Node2D = ennemis[i]
	if not is_instance_valid(e):
		var last_invalid: int = ennemis.size() - 1
		ennemis[i] = ennemis[last_invalid]
		ennemis.remove_at(last_invalid)
		return true

	var d2: float = joueur.global_position.distance_squared_to(e.global_position)

	# zone proche: ne touche pas à l'ennemi ici, il est géré par _appliquer_lod()
	if d2 <= r2_sim:
		return false

	# zone moyenne: IA coupée, collisions coupées si besoin, marche lente simulée
	if d2 <= r2_disp:
		_activer_ennemi(e, false)
		if freq_lointain_frames > 0 and (tour_budget % freq_lointain_frames) == 0:
			_tick_lointain(e)
		return false

	# trop loin: on pool
	var doit_decrementer := false
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

func _position_spawn() -> Vector2:
	var a: float = hasard.randf_range(0.0, TAU)
	var r: float = hasard.randf_range(rayon_spawn_min, rayon_spawn_max)
	return joueur.global_position + Vector2(cos(a), sin(a)) * r

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
	for i: int in range(poids_types.size()):
		s += poids_types[i]
		if x <= s:
			return i

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
	for i: int in range(p.size()):
		s += p[i]
		if x <= s:
			return i

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

func _generer_loot_pour_ennemi(e: Node2D) -> void:
	if scene_loot == null:
		return
	if not (e is Enemy):
		return

	var ennemi := e as Enemy
	var type_ennemi: int = ennemi.type_ennemi

	# TODO : quand tu auras un niveau sur l'ennemi, tu remplaces 1 par ennemi.niveau
	var niveau: int = 1
	var luck: float = _get_player_luck()

	var nb_rolls: int = _tirer_nombre_rolls(type_ennemi, niveau)
	if nb_rolls <= 0:
		return

	for i in range(nb_rolls):
		var rarete: int = _tirer_rarete(type_ennemi, niveau, luck)
		var type_item: int = _tirer_type_item(rarete)
		var item_id: StringName = _tirer_item_id(type_item, rarete)

		if String(item_id) == "":
			continue

		var loot: Loot = scene_loot.instantiate() as Loot
		if loot == null:
			continue

		loot.type_loot = rarete
		loot.type_item = type_item
		loot.item_id = item_id
		loot.quantite = 1

		var offset := Vector2(
			hasard.randf_range(-16.0, 16.0),
			hasard.randf_range(-16.0, 16.0)
		)
		loot.global_position = ennemi.global_position + offset

		get_tree().current_scene.add_child(loot)


func _tirer_nombre_rolls(type_ennemi: int, niveau: int) -> int:
	var min_r := 0
	var max_r := 0

	match type_ennemi:
		Enemy.TypeEnnemi.C:
			min_r = 0
			max_r = 2
		Enemy.TypeEnnemi.B:
			min_r = 1
			max_r = 3
		Enemy.TypeEnnemi.A:
			min_r = 2
			max_r = 4
		Enemy.TypeEnnemi.S:
			min_r = 3
			max_r = 5
		Enemy.TypeEnnemi.BOSS:
			min_r = 5
			max_r = 8
		_:
			min_r = 0
			max_r = 1

	# petit bonus de rolls tous les 10 niveaux
	var bonus := int(max(niveau - 1, 0) / 10)
	max_r += bonus

	if max_r < min_r:
		max_r = min_r

	if max_r <= min_r:
		return min_r

	return hasard.randi_range(min_r, max_r)


func _proba_rarete_base(type_ennemi: int) -> PackedFloat32Array:
	match type_ennemi:
		Enemy.TypeEnnemi.C:
			return PackedFloat32Array([0.85, 0.13, 0.02, 0.0])
		Enemy.TypeEnnemi.B:
			return PackedFloat32Array([0.70, 0.25, 0.04, 0.01])
		Enemy.TypeEnnemi.A:
			return PackedFloat32Array([0.50, 0.35, 0.12, 0.03])
		Enemy.TypeEnnemi.S:
			return PackedFloat32Array([0.30, 0.40, 0.22, 0.08])
		Enemy.TypeEnnemi.BOSS:
			return PackedFloat32Array([0.0, 0.40, 0.40, 0.20])
		_:
			return PackedFloat32Array([1.0, 0.0, 0.0, 0.0])


func _get_player_luck() -> float:
	if joueur != null and is_instance_valid(joueur) and joueur.has_method("get_luck"):
		return float(joueur.get_luck())
	return 0.0


func _tirer_rarete(type_ennemi: int, niveau: int, luck: float) -> int:
	var p: PackedFloat32Array = _proba_rarete_base(type_ennemi)
	if p.size() < 4:
		return Loot.TypeLoot.C

	var pC: float = p[0]
	var pB: float = p[1]
	var pA: float = p[2]
	var pS: float = p[3]

	# 1) bonus de niveau : on déplace un peu de C vers B/A/S
	var steps: int = int(max(niveau - 1, 0) / 5)
	var bonus: float = float(steps) * 0.05
	var shift: float = min(bonus, pC - 0.1)
	if shift > 0.0:
		pC -= shift
		pB += shift * 0.5
		pA += shift * 0.3
		pS += shift * 0.2

	# 2) chance joueur : buff léger A/S
	if luck > 0.0:
		var luck_factor = clamp(luck, 0.0, 100.0) / 100.0
		var bonusA: float = 0.05 * luck_factor
		var bonusS: float = 0.02 * luck_factor
		var total_bonus: float = bonusA + bonusS

		var max_deplacable: float = pC * 0.7 + pB * 0.3
		var reduc: float = min(total_bonus, max_deplacable)

		var fromC: float = min(pC, reduc * 0.7)
		var fromB: float = min(pB, reduc * 0.3)
		pC -= fromC
		pB -= fromB
		pA += bonusA
		pS += bonusS

	# normalisation
	var sum: float = pC + pB + pA + pS
	if sum <= 0.0:
		return Loot.TypeLoot.C

	pC /= sum
	pB /= sum
	pA /= sum
	pS /= sum

	var x: float = hasard.randf()
	if x < pC:
		return Loot.TypeLoot.C
	x -= pC
	if x < pB:
		return Loot.TypeLoot.B
	x -= pB
	if x < pA:
		return Loot.TypeLoot.A
	return Loot.TypeLoot.S


func _tirer_type_item(rarete: int) -> int:
	var x: float = hasard.randf()
	match rarete:
		Loot.TypeLoot.C:
			if x < 0.7:
				return Loot.TypeItem.CONSO
			elif x < 0.9:
				return Loot.TypeItem.UPGRADE
			else:
				return Loot.TypeItem.ARME
		Loot.TypeLoot.B:
			if x < 0.4:
				return Loot.TypeItem.CONSO
			elif x < 0.8:
				return Loot.TypeItem.UPGRADE
			else:
				return Loot.TypeItem.ARME
		Loot.TypeLoot.A:
			if x < 0.3:
				return Loot.TypeItem.CONSO
			elif x < 0.7:
				return Loot.TypeItem.UPGRADE
			else:
				return Loot.TypeItem.ARME
		Loot.TypeLoot.S:
			if x < 0.1:
				return Loot.TypeItem.CONSO
			elif x < 0.5:
				return Loot.TypeItem.UPGRADE
			else:
				return Loot.TypeItem.ARME
	return Loot.TypeItem.CONSO


func _d_loot(msg: String) -> void:
	if debug_loot:
		print(msg)

func _tirer_item_id(type_item: int, rarete: int) -> StringName:
	if type_item == Loot.TypeItem.CONSO:
		var x := hasard.randf()
		match rarete:
			Loot.TypeLoot.C:
				if x < 0.45:
					return &"conso_heal_full_1"
				elif x < 0.75:
					return &"conso_regen_1"
				elif x < 0.95:
					return &"conso_overheal_1"
				else:
					return &"conso_invincible_1"

			Loot.TypeLoot.B:
				if x < 0.35:
					return &"conso_heal_full_2"
				elif x < 0.65:
					return &"conso_regen_2"
				elif x < 0.85:
					return &"conso_overheal_1"
				elif x < 0.95:
					return &"conso_invincible_1"
				else:
					return &"conso_rage_1"

			Loot.TypeLoot.A:
				if x < 0.30:
					return &"conso_heal_full_3"
				elif x < 0.55:
					return &"conso_regen_3"
				elif x < 0.75:
					return &"conso_overheal_2"
				elif x < 0.90:
					return &"conso_invincible_2"
				else:
					return &"conso_rage_2"

			Loot.TypeLoot.S:
				if x < 0.25:
					return &"conso_overheal_3"
				elif x < 0.50:
					return &"conso_invincible_3"
				elif x < 0.75:
					return &"conso_rage_3"
				elif x < 0.90:
					return &"conso_heal_full_3"
				else:
					return &"conso_regen_3"

		return &"conso_heal_full_1"

	elif type_item == Loot.TypeItem.UPGRADE:
		match rarete:
			Loot.TypeLoot.C:
				return &"upgrade_c"
			Loot.TypeLoot.B:
				return &"upgrade_b"
			Loot.TypeLoot.A:
				return &"upgrade_a"
			Loot.TypeLoot.S:
				return &"upgrade_s"
		return &"upgrade_c"

	elif type_item == Loot.TypeItem.ARME:
		match rarete:
			Loot.TypeLoot.C:
				return &"arme_c"
			Loot.TypeLoot.B:
				return &"arme_b"
			Loot.TypeLoot.A:
				return &"arme_a"
			Loot.TypeLoot.S:
				return &"arme_s"
		return &"arme_c"

	return &""
