extends Area2D
class_name ZoneRamassage

@export var debug_enabled := false
var pickables: Array[Node2D] = []

func _d(m:String)->void:
	if debug_enabled: print("[ZoneRamassage]", Time.get_ticks_msec(), m)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _root_candidate(a: Area2D) -> Node2D:
	if a is Loot:
		return a as Node2D

	var p := a.get_parent()
	if p is Loot:
		return p as Node2D

	var root := a.get_owner()
	if root is Loot:
		return root as Node2D

	if p is ArmeBase:
		return p
	if root is ArmeBase:
		return root

	return null

func _on_area_entered(a: Area2D) -> void:
	var c := _root_candidate(a)
	if c and not pickables.has(c):
		pickables.append(c)
		_d("ENTER %s count=%d" % [c.name, pickables.size()])

func _on_area_exited(a: Area2D) -> void:
	var c := _root_candidate(a)
	if c:
		pickables.erase(c)
		_d("EXIT %s count=%d" % [c.name, pickables.size()])

func get_pickable_le_plus_proche(ref_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var dmin := INF
	for n in pickables:
		if not is_instance_valid(n): continue
		var d := ref_pos.distance_squared_to(n.global_position)
		if d < dmin: dmin = d; best = n
	return best
