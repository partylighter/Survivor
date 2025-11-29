extends Node
class_name GestionnaireLootDrops

@export var scene_loot: PackedScene
@export var debug_loot: bool = false

@export_group("Loot: Rolls par type")
@export var rolls_min_C: int = 0
@export var rolls_max_C: int = 2
@export var rolls_min_B: int = 1
@export var rolls_max_B: int = 3
@export var rolls_min_A: int = 2
@export var rolls_max_A: int = 4
@export var rolls_min_S: int = 3
@export var rolls_max_S: int = 5
@export var rolls_min_BOSS: int = 5
@export var rolls_max_BOSS: int = 8
@export var rolls_bonus_par_10_niveaux: int = 1
@export var mult_rolls_global: float = 1.0

@export_group("Loot: Multiplicateurs rareté globale")
@export var mult_rarete_C: float = 1.0
@export var mult_rarete_B: float = 1.0
@export var mult_rarete_A: float = 1.0
@export var mult_rarete_S: float = 1.0

@export_group("Loot: Poids type d'item")
@export var mult_type_conso: float = 1.0
@export var mult_type_upgrade: float = 1.0
@export var mult_type_arme: float = 1.0

var _rng: RandomNumberGenerator = null

func generer_loot_pour_ennemi(e: Node2D, rng: RandomNumberGenerator, joueur: Node2D) -> void:
	if scene_loot == null:
		return
	if not (e is Enemy):
		return

	_rng = rng

	var ennemi := e as Enemy
	var type_ennemi: int = ennemi.type_ennemi

	var niveau: int = 1
	var luck: float = _get_player_luck(joueur)

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
			_rng.randf_range(-16.0, 16.0),
			_rng.randf_range(-16.0, 16.0)
		)
		loot.global_position = ennemi.global_position + offset

		get_tree().current_scene.add_child(loot)

func _tirer_nombre_rolls(type_ennemi: int, niveau: int) -> int:
	var min_r := 0
	var max_r := 0

	match type_ennemi:
		Enemy.TypeEnnemi.C:
			min_r = rolls_min_C
			max_r = rolls_max_C
		Enemy.TypeEnnemi.B:
			min_r = rolls_min_B
			max_r = rolls_max_B
		Enemy.TypeEnnemi.A:
			min_r = rolls_min_A
			max_r = rolls_max_A
		Enemy.TypeEnnemi.S:
			min_r = rolls_min_S
			max_r = rolls_max_S
		Enemy.TypeEnnemi.BOSS:
			min_r = rolls_min_BOSS
			max_r = rolls_max_BOSS
		_:
			min_r = 0
			max_r = 1

	var bonus := int(max(niveau - 1, 0) / 10) * rolls_bonus_par_10_niveaux
	max_r += bonus

	if max_r < min_r:
		max_r = min_r

	if max_r <= min_r:
		var base_rolls := min_r
		var nb := int(round(float(base_rolls) * mult_rolls_global))
		return max(0, nb)

	var base := _rng.randi_range(min_r, max_r)
	var nb_final := int(round(float(base) * mult_rolls_global))
	return max(0, nb_final)

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

func _get_player_luck(joueur: Node2D) -> float:
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

	var steps: int = int(max(niveau - 1, 0) / 5)
	var bonus: float = float(steps) * 0.05
	var shift: float = min(bonus, pC - 0.1)
	if shift > 0.0:
		pC -= shift
		pB += shift * 0.5
		pA += shift * 0.3
		pS += shift * 0.2

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

	pC *= mult_rarete_C
	pB *= mult_rarete_B
	pA *= mult_rarete_A
	pS *= mult_rarete_S

	var sum: float = pC + pB + pA + pS
	if sum <= 0.0:
		return Loot.TypeLoot.C

	pC /= sum
	pB /= sum
	pA /= sum
	pS /= sum

	var x: float = _rng.randf()
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
	var w_conso: float = 0.0
	var w_upgrade: float = 0.0
	var w_arme: float = 0.0

	match rarete:
		Loot.TypeLoot.C:
			w_conso = 0.7
			w_upgrade = 0.2
			w_arme = 0.1
		Loot.TypeLoot.B:
			w_conso = 0.4
			w_upgrade = 0.4
			w_arme = 0.2
		Loot.TypeLoot.A:
			w_conso = 0.3
			w_upgrade = 0.4
			w_arme = 0.3
		Loot.TypeLoot.S:
			w_conso = 0.1
			w_upgrade = 0.4
			w_arme = 0.5
		_:
			w_conso = 1.0
			w_upgrade = 0.0
			w_arme = 0.0

	w_conso *= mult_type_conso
	w_upgrade *= mult_type_upgrade
	w_arme *= mult_type_arme

	var sum := w_conso + w_upgrade + w_arme
	if sum <= 0.0:
		return Loot.TypeItem.CONSO

	w_conso /= sum
	w_upgrade /= sum
	w_arme /= sum

	var x := _rng.randf()
	if x < w_conso:
		return Loot.TypeItem.CONSO
	x -= w_conso
	if x < w_upgrade:
		return Loot.TypeItem.UPGRADE
	return Loot.TypeItem.ARME

func _d_loot(msg: String) -> void:
	if debug_loot:
		print(msg)

func _tirer_item_id(type_item: int, rarete: int) -> StringName:
	if type_item == Loot.TypeItem.CONSO:
		var x := _rng.randf()
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
