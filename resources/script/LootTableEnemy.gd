extends Resource
class_name LootTableEnemy

@export_group("Probabilités de rareté")
@export_range(0.0, 1.0, 0.01) var proba_C: float = 1.0
@export_range(0.0, 1.0, 0.01) var proba_B: float = 0.0
@export_range(0.0, 1.0, 0.01) var proba_A: float = 0.0
@export_range(0.0, 1.0, 0.01) var proba_S: float = 0.0

@export_group("Conso par rareté")
@export var conso_C: Array[LootItemEntry] = []
@export var conso_B: Array[LootItemEntry] = []
@export var conso_A: Array[LootItemEntry] = []
@export var conso_S: Array[LootItemEntry] = []

@export_group("Upgrades par rareté")
@export var upgrade_C: Array[LootItemEntry] = []
@export var upgrade_B: Array[LootItemEntry] = []
@export var upgrade_A: Array[LootItemEntry] = []
@export var upgrade_S: Array[LootItemEntry] = []

@export_group("Armes par rareté")
@export var arme_C: Array[LootItemEntry] = []
@export var arme_B: Array[LootItemEntry] = []
@export var arme_A: Array[LootItemEntry] = []
@export var arme_S: Array[LootItemEntry] = []

func tirer_item_id(type_item: int, rarete: int, rng: RandomNumberGenerator) -> StringName:
	var pool: Array[LootItemEntry] = []

	if type_item == Loot.TypeItem.CONSO:
		match rarete:
			Loot.TypeLoot.C:
				pool = conso_C
			Loot.TypeLoot.B:
				pool = conso_B
			Loot.TypeLoot.A:
				pool = conso_A
			Loot.TypeLoot.S:
				pool = conso_S
	elif type_item == Loot.TypeItem.UPGRADE:
		match rarete:
			Loot.TypeLoot.C:
				pool = upgrade_C
			Loot.TypeLoot.B:
				pool = upgrade_B
			Loot.TypeLoot.A:
				pool = upgrade_A
			Loot.TypeLoot.S:
				pool = upgrade_S
	elif type_item == Loot.TypeItem.ARME:
		match rarete:
			Loot.TypeLoot.C:
				pool = arme_C
			Loot.TypeLoot.B:
				pool = arme_B
			Loot.TypeLoot.A:
				pool = arme_A
			Loot.TypeLoot.S:
				pool = arme_S

	if pool.is_empty():
		return &""

	return _tirer_dans_pool(pool, rng)

func _tirer_dans_pool(pool: Array[LootItemEntry], rng: RandomNumberGenerator) -> StringName:
	if pool.is_empty():
		return &""

	var total_poids: float = 0.0
	for entry: LootItemEntry in pool:
		if entry != null:
			total_poids += max(entry.poids, 0.0)

	if total_poids <= 0.0:
		var first := pool[0]
		if first != null:
			return first.item_id
		return &""

	var x: float = rng.randf() * total_poids
	var cumul: float = 0.0

	for entry: LootItemEntry in pool:
		if entry == null:
			continue
		var w: float = max(entry.poids, 0.0)
		if w <= 0.0:
			continue
		cumul += w
		if x <= cumul:
			return entry.item_id

	var last = pool[pool.size() - 1]
	if last != null:
		return last.item_id
	return &""
