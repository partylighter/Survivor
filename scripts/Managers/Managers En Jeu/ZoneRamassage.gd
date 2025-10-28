extends Area2D
class_name ZoneRamassage

var loot_dans_zone: Array[LootArme] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is LootArme and not loot_dans_zone.has(body):
		loot_dans_zone.append(body)

func _on_body_exited(body: Node) -> void:
	if body is LootArme:
		loot_dans_zone.erase(body)

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
	return meilleur
