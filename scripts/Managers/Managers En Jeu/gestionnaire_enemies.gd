extends Node2D
class_name GestionnaireEnnemis

signal ennemi_cree(e)
signal ennemi_tue(e)
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
@export var budget_par_frame: int = 200

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

var ennemis: Array[Node2D] = []
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
	_maj_budget()

func _tick_vague(dt: float) -> void:
	t_vague += dt
	var taux: float = _taux_courant()
	acc_vague += taux * dt
	while acc_vague >= 1.0:
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

func _creer_ennemi() -> void:
	if scenes_ennemis.is_empty():
		return
	var idx: int = _choisir_type()
	var e: Node2D = scenes_ennemis[idx].instantiate() as Node2D
	e.global_position = _position_spawn()
	add_child(e)
	ennemis.append(e)
	e.set_meta("vague_id", i_vague if mode_vagues else -1)
	if e.has_signal("mort"):
		e.connect("mort", Callable(self, "_sur_mort").bind(e))
	emit_signal("ennemi_cree", e)

func _creer_ennemi_index(idx: int, rmin: float, rmax: float) -> Node2D:
	if scenes_ennemis.is_empty():
		return null
	idx = clamp(idx, 0, scenes_ennemis.size() - 1)
	var e: Node2D = scenes_ennemis[idx].instantiate() as Node2D
	e.global_position = _position_spawn_rayon(rmin, rmax)
	add_child(e)
	ennemis.append(e)
	e.set_meta("vague_id", i_vague if mode_vagues else -1)
	if e.has_signal("mort"):
		e.connect("mort", Callable(self, "_sur_mort").bind(e))
	emit_signal("ennemi_cree", e)
	return e

func _sur_mort(e: Node2D) -> void:
	ennemis.erase(e)
	if e.has_meta("vague_id"):
		var v: Variant = e.get_meta("vague_id")
		if typeof(v) == TYPE_INT and int(v) == i_vague:
			vivants_vague = max(0, vivants_vague - 1)
			tues_vague += 1
	e.queue_free()
	emit_signal("ennemi_tue", e)

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

func _eval_ou_supprime(i: int, r2_sim: float, r2_disp: float) -> bool:
	if i < 0 or i >= ennemis.size():
		return false
	var e: Node2D = ennemis[i]
	var d2: float = joueur.global_position.distance_squared_to(e.global_position)
	e.set_process(d2 <= r2_sim)
	if d2 > r2_disp:
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
		e.queue_free()
		return true
	return false

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
	for i: int in poids_types.size():
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
	for i: int in p.size():
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
	return max(taux_vagues.size(), max(durees_vagues.size(), max(max_vivants_vagues.size(), max(total_max_vagues.size(), cibles_tues_vagues.size()))))

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
