extends Area2D
class_name ZoneRamassage

@export var debug_enabled := false
var pickables: Array[Node2D] = []

func _d(m: String) -> void:
	if debug_enabled:
		print("[ZoneRamassage] ", Time.get_ticks_msec(), " ", m)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _root_candidate(a: Area2D) -> Node2D:
	if a == null:
		return null

	var p: Node = a.get_parent()
	if p is Loot:
		return p as Node2D

	var root: Node = a.owner
	if root is Loot:
		return root as Node2D

	if p is ArmeBase:
		return p as Node2D
	if root is ArmeBase:
		return root as Node2D
	if p is EquipementAuSol:
		return p as Node2D
	if root is EquipementAuSol:
		return root as Node2D

	return null

func _on_area_entered(a: Area2D) -> void:
	var c := _root_candidate(a)
	enregistrer_pickable(c)

func enregistrer_pickable(c: Node2D) -> void:
	if c != null and not pickables.has(c):
		pickables.append(c)
		_d("ENTER %s count=%d" % [c.name, pickables.size()])

func _on_area_exited(a: Area2D) -> void:
	var c := _root_candidate(a)
	if c != null:
		pickables.erase(c)
		_d("EXIT %s count=%d" % [c.name, pickables.size()])

func get_pickable_le_plus_proche(ref_pos: Vector2, filtre: Callable = Callable()) -> Node2D:
	var best: Node2D = null
	var dmin: float = INF
	for index: int in range(pickables.size() - 1, -1, -1):
		var objet: Node2D = pickables[index]
		if not is_instance_valid(objet):
			pickables.remove_at(index)
			continue
		if not _est_pickable_valide(objet):
			continue
		if filtre.is_valid() and not bool(filtre.call(objet)):
			continue
		var d: float = ref_pos.distance_squared_to(objet.global_position)
		if d < dmin:
			dmin = d
			best = objet
	return best

func _est_pickable_valide(objet: Node2D) -> bool:
	if objet.has_meta("pickup_locked") and bool(objet.get_meta("pickup_locked")):
		return false
	if objet.has_meta("equipped") and bool(objet.get_meta("equipped")):
		return false
	if objet.is_in_group("__arme_equipee__"):
		return false
	if objet is ArmeBase and not (objet as ArmeBase).est_au_sol:
		return false
	if objet.has_method("est_ramassable"):
		return bool(objet.call("est_ramassable"))
	if objet is Loot:
		return (objet as Loot).est_actif_pour_manager()
	return objet is ArmeBase
