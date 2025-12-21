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
			Loot.TypeLoot.C: pool = conso_C
			Loot.TypeLoot.B: pool = conso_B
			Loot.TypeLoot.A: pool = conso_A
			Loot.TypeLoot.S: pool = conso_S
	elif type_item == Loot.TypeItem.UPGRADE:
		match rarete:
			Loot.TypeLoot.C: pool = upgrade_C
			Loot.TypeLoot.B: pool = upgrade_B
			Loot.TypeLoot.A: pool = upgrade_A
			Loot.TypeLoot.S: pool = upgrade_S
	elif type_item == Loot.TypeItem.ARME:
		match rarete:
			Loot.TypeLoot.C: pool = arme_C
			Loot.TypeLoot.B: pool = arme_B
			Loot.TypeLoot.A: pool = arme_A
			Loot.TypeLoot.S: pool = arme_S

	if pool.is_empty():
		return &""

	return _tirer_dans_pool(pool, rng)

func _tirer_dans_pool(pool: Array[LootItemEntry], rng: RandomNumberGenerator) -> StringName:
	if pool.is_empty():
		return &""

	var total_poids: float = 0.0
	for entry: LootItemEntry in pool:
		if entry != null:
			total_poids += maxf(entry.poids, 0.0)

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
		var w: float = maxf(entry.poids, 0.0)
		if w <= 0.0:
			continue
		cumul += w
		if x <= cumul:
			return entry.item_id

	var last := pool[pool.size() - 1]
	if last != null:
		return last.item_id
	return &""

func tirer_loot(
	rarete: int,
	rng: RandomNumberGenerator,
	mult_conso: float = 1.0,
	mult_upgrade: float = 1.0,
	mult_arme: float = 1.0
) -> Dictionary:
	var pool_conso := _get_pool(Loot.TypeItem.CONSO, rarete)
	var pool_upgrade := _get_pool(Loot.TypeItem.UPGRADE, rarete)
	var pool_arme := _get_pool(Loot.TypeItem.ARME, rarete)

	var w_conso := _poids_pool(pool_conso) * maxf(mult_conso, 0.0)
	var w_upgrade := _poids_pool(pool_upgrade) * maxf(mult_upgrade, 0.0)
	var w_arme := _poids_pool(pool_arme) * maxf(mult_arme, 0.0)

	var sum := w_conso + w_upgrade + w_arme
	if sum <= 0.0:
		return {"type_item": Loot.TypeItem.CONSO, "item_id": &""}

	var x := rng.randf() * sum

	var type_item: int
	var pool: Array[LootItemEntry]

	if x < w_conso:
		type_item = Loot.TypeItem.CONSO
		pool = pool_conso
	elif x < w_conso + w_upgrade:
		type_item = Loot.TypeItem.UPGRADE
		pool = pool_upgrade
	else:
		type_item = Loot.TypeItem.ARME
		pool = pool_arme

	var item_id: StringName = _tirer_dans_pool(pool, rng)
	return {"type_item": type_item, "item_id": item_id}

func get_entry(type_item: int, rarete: int, item_id: StringName) -> LootItemEntry:
	var pool: Array[LootItemEntry] = _get_pool(type_item, rarete)
	for e: LootItemEntry in pool:
		if e != null and e.item_id == item_id:
			return e
	return null

func _get_pool(type_item: int, rarete: int) -> Array[LootItemEntry]:
	if type_item == Loot.TypeItem.CONSO:
		match rarete:
			Loot.TypeLoot.C: return conso_C
			Loot.TypeLoot.B: return conso_B
			Loot.TypeLoot.A: return conso_A
			Loot.TypeLoot.S: return conso_S
	elif type_item == Loot.TypeItem.UPGRADE:
		match rarete:
			Loot.TypeLoot.C: return upgrade_C
			Loot.TypeLoot.B: return upgrade_B
			Loot.TypeLoot.A: return upgrade_A
			Loot.TypeLoot.S: return upgrade_S
	elif type_item == Loot.TypeItem.ARME:
		match rarete:
			Loot.TypeLoot.C: return arme_C
			Loot.TypeLoot.B: return arme_B
			Loot.TypeLoot.A: return arme_A
			Loot.TypeLoot.S: return arme_S
	return []

func _poids_pool(pool: Array[LootItemEntry]) -> float:
	if pool.is_empty():
		return 0.0
	var total: float = 0.0
	for entry: LootItemEntry in pool:
		if entry == null:
			continue
		total += maxf(entry.poids, 0.0)
	if total <= 0.0:
		return float(pool.size())
	return total
