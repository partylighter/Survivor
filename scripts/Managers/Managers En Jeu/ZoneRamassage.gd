# ZoneRamassage.gd
extends Area2D
class_name ZoneRamassage

@export var debug_enabled: bool = true

var loot_dans_zone: Array[LootArme] = []

func _d(m:String)->void:
	if debug_enabled: print("[ZoneRamassage]", Time.get_ticks_msec(), m)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_d("READY layer=" + str(collision_layer) + " mask=" + str(collision_mask))

func _on_area_entered(a: Area2D) -> void:
	if a is LootArme and not loot_dans_zone.has(a):
		loot_dans_zone.append(a)
		_d("ENTER " + a.name + " count=" + str(loot_dans_zone.size()))

func _on_area_exited(a: Area2D) -> void:
	if a is LootArme:
		loot_dans_zone.erase(a)
		_d("EXIT " + a.name + " count=" + str(loot_dans_zone.size()))

func get_loot_le_plus_proche(ref_pos: Vector2) -> LootArme:
	var meilleur: LootArme = null
	var dist_min: float = INF
	for l in loot_dans_zone:
		if not is_instance_valid(l):
			continue
		var d: float = ref_pos.distance_squared_to(l.global_position)
		if d < dist_min:
			dist_min = d
			meilleur = l
	if meilleur:
		_d("BEST name=" + meilleur.name + " d2=" + str(dist_min) + " ref=" + str(ref_pos))
	else:
		_d("BEST none ref=" + str(ref_pos))
	return meilleur
