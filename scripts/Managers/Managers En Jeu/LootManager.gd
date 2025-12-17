extends Node
class_name LootManager

const ACT_RIEN: int = 0
const ACT_VERS_AIMANT: int = 1
const ACT_SUPPRIMER: int = 2

@export var chemin_joueur: NodePath
@export var scan_frames: int = 6
@export var max_idle_updates_per_frame: int = 0
@export var rayon_activation_loot_px: float = 900.0

var joueur: Node2D = null
var loot_target: Node2D = null

var _loots_attente: Array[Loot] = []
var _loots_aimant: Array[Loot] = []
var _curseur_attente: int = 0

func _enter_tree() -> void:
	add_to_group("loot_manager")

func _ready() -> void:
	_resoudre_joueur()
	_enregistrer_loots_existants()
	set_physics_process(true)

func _resoudre_joueur() -> void:
	var ancien: Node2D = joueur
	joueur = get_node_or_null(chemin_joueur) as Node2D

	if joueur != ancien and joueur != null and is_instance_valid(joueur):
		for l: Loot in _loots_attente:
			if l != null and is_instance_valid(l):
				l.joueur_cible = joueur
		for l2: Loot in _loots_aimant:
			if l2 != null and is_instance_valid(l2):
				l2.joueur_cible = joueur

	_resoudre_loot_target()

func _resoudre_loot_target() -> void:
	loot_target = null
	if joueur != null and is_instance_valid(joueur):
		var n: Node = joueur.get_node_or_null("LootTarget")
		if n is Node2D:
			loot_target = n as Node2D

func _pos_pickup() -> Vector2:
	if loot_target != null and is_instance_valid(loot_target):
		return loot_target.global_position
	if joueur != null and is_instance_valid(joueur):
		return joueur.global_position
	return Vector2.ZERO

func _enregistrer_loots_existants() -> void:
	var nodes: Array = get_tree().get_nodes_in_group("loots")
	for n: Node in nodes:
		var l := n as Loot
		if l != null:
			enregistrer_loot(l)

func enregistrer_loot(l: Loot) -> void:
	if l == null or l._lm != null:
		return

	l._lm = self
	l._lm_liste = 0
	l._lm_index = _loots_attente.size()
	_loots_attente.append(l)

	if joueur != null and is_instance_valid(joueur):
		l.joueur_cible = joueur

func retirer_loot(l: Loot) -> void:
	if l == null or l._lm != self:
		return

	if l._lm_liste == 0:
		_swap_remove(_loots_attente, l._lm_index, 0)
	else:
		_swap_remove(_loots_aimant, l._lm_index, 1)

	l._lm = null
	l._lm_liste = -1
	l._lm_index = -1

func _swap_remove(arr: Array[Loot], idx: int, list_id: int) -> void:
	var last_i: int = arr.size() - 1
	if idx < 0 or idx > last_i:
		return

	if idx != last_i:
		var last: Loot = arr[last_i]
		arr[idx] = last
		last._lm_liste = list_id
		last._lm_index = idx

	arr.remove_at(last_i)

	if list_id == 0 and _curseur_attente > idx:
		_curseur_attente = maxi(0, _curseur_attente - 1)
	if list_id == 0 and _curseur_attente >= arr.size():
		_curseur_attente = 0

func _physics_process(dt: float) -> void:
	if joueur == null or not is_instance_valid(joueur):
		_resoudre_joueur()
		if joueur == null or not is_instance_valid(joueur):
			return

	if loot_target == null or not is_instance_valid(loot_target):
		_resoudre_loot_target()

	var pos: Vector2 = _pos_pickup()

	var i: int = 0
	while i < _loots_aimant.size():
		var loot_a: Loot = _loots_aimant[i]
		if loot_a == null or not is_instance_valid(loot_a) or loot_a._lm != self:
			_swap_remove(_loots_aimant, i, 1)
			continue

		var action_a: int = loot_a.tick_aimant(dt, pos)
		if action_a == ACT_SUPPRIMER:
			retirer_loot(loot_a)
			continue

		i += 1

	var nb_attente: int = _loots_attente.size()
	if nb_attente == 0:
		return

	var budget: int = max_idle_updates_per_frame
	if budget <= 0:
		var sf: int = maxi(1, scan_frames)
		budget = int(ceil(float(nb_attente) / float(sf)))

	var loops: int = mini(budget, nb_attente)

	var r2_act: float = rayon_activation_loot_px * rayon_activation_loot_px
	var activer_tout: bool = rayon_activation_loot_px <= 0.0

	var k: int = 0
	while k < loops and _loots_attente.size() > 0:
		if _curseur_attente >= _loots_attente.size():
			_curseur_attente = 0

		var loot: Loot = _loots_attente[_curseur_attente]
		if loot == null or not is_instance_valid(loot) or loot._lm != self:
			_curseur_attente += 1
			k += 1
			continue

		if not activer_tout:
			var d2_act: float = joueur.global_position.distance_squared_to(loot.global_position)
			if d2_act > r2_act:
				if loot.tick_lointain():
					retirer_loot(loot)
				else:
					_curseur_attente += 1
				k += 1
				continue

		var action: int = loot.tick_attente(dt, pos)

		if action == ACT_VERS_AIMANT:
			_swap_remove(_loots_attente, loot._lm_index, 0)
			loot._lm_liste = 1
			loot._lm_index = _loots_aimant.size()
			_loots_aimant.append(loot)
		elif action == ACT_SUPPRIMER:
			retirer_loot(loot)
		else:
			_curseur_attente += 1

		k += 1
