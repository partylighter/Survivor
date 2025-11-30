extends Node
class_name GestionnaireLootDrops

@export var scene_loot: PackedScene
@export var debug_loot: bool = false

@export_group("Loot: Tirages par type d'ennemi")
@export var tirages_min_type_C: int = 0
@export var tirages_max_type_C: int = 2
@export var tirages_min_type_B: int = 1
@export var tirages_max_type_B: int = 3
@export var tirages_min_type_A: int = 2
@export var tirages_max_type_A: int = 4
@export var tirages_min_type_S: int = 3
@export var tirages_max_type_S: int = 5
@export var tirages_min_type_BOSS: int = 5
@export var tirages_max_type_BOSS: int = 8
@export var tirages_bonus_par_10_niveaux: int = 1
@export var multiplicateur_tirages_global: float = 1.0

@export_group("Loot: Multiplicateurs de rareté globale")
@export var multiplicateur_rarete_C: float = 1.0
@export var multiplicateur_rarete_B: float = 1.0
@export var multiplicateur_rarete_A: float = 1.0
@export var multiplicateur_rarete_S: float = 1.0

@export_group("Loot: Poids par type d'item")
@export var multiplicateur_type_conso: float = 1.0
@export var multiplicateur_type_upgrade: float = 1.0
@export var multiplicateur_type_arme: float = 1.0

var _generateur_aleatoire: RandomNumberGenerator

func generer_loot_pour_ennemi(e: Node2D, rng: RandomNumberGenerator, joueur: Node2D) -> void:
	if scene_loot == null:
		return
	if not (e is Enemy):
		return

	_generateur_aleatoire = rng

	var ennemi := e as Enemy
	var type_ennemi: int = ennemi.type_ennemi

	var niveau_zone: int = 1
	var chance_joueur: float = _get_player_luck(joueur)

	var nb_tirages: int = _tirer_nombre_rolls(type_ennemi, niveau_zone)
	if nb_tirages <= 0:
		return

	for i in range(nb_tirages):
		var rarete: int = _tirer_rarete(type_ennemi, niveau_zone, chance_joueur)
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
			_generateur_aleatoire.randf_range(-16.0, 16.0),
			_generateur_aleatoire.randf_range(-16.0, 16.0)
		)
		loot.global_position = ennemi.global_position + offset

		get_tree().current_scene.add_child(loot)

func _tirer_nombre_rolls(type_ennemi: int, niveau_zone: int) -> int:
	var nb_tirages_min := 0
	var nb_tirages_max := 0

	match type_ennemi:
		Enemy.TypeEnnemi.C:
			nb_tirages_min = tirages_min_type_C
			nb_tirages_max = tirages_max_type_C
		Enemy.TypeEnnemi.B:
			nb_tirages_min = tirages_min_type_B
			nb_tirages_max = tirages_max_type_B
		Enemy.TypeEnnemi.A:
			nb_tirages_min = tirages_min_type_A
			nb_tirages_max = tirages_max_type_A
		Enemy.TypeEnnemi.S:
			nb_tirages_min = tirages_min_type_S
			nb_tirages_max = tirages_max_type_S
		Enemy.TypeEnnemi.BOSS:
			nb_tirages_min = tirages_min_type_BOSS
			nb_tirages_max = tirages_max_type_BOSS
		_:
			nb_tirages_min = 0
			nb_tirages_max = 1

	var bonus_niveau := int(max(niveau_zone - 1, 0) / 10) * tirages_bonus_par_10_niveaux
	nb_tirages_max += bonus_niveau

	if nb_tirages_max < nb_tirages_min:
		nb_tirages_max = nb_tirages_min

	if nb_tirages_max <= nb_tirages_min:
		var nb_base_tirages := nb_tirages_min
		var nb_tirages := int(round(float(nb_base_tirages) * multiplicateur_tirages_global))
		return max(0, nb_tirages)

	var nb_tirages_brut := _generateur_aleatoire.randi_range(nb_tirages_min, nb_tirages_max)
	var nb_tirages_final := int(round(float(nb_tirages_brut) * multiplicateur_tirages_global))
	return max(0, nb_tirages_final)

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

func _tirer_rarete(type_ennemi: int, niveau_zone: int, chance_joueur: float) -> int:
	var proba_base: PackedFloat32Array = _proba_rarete_base(type_ennemi)
	if proba_base.size() < 4:
		return Loot.TypeLoot.C

	var proba_C: float = proba_base[0]
	var proba_B: float = proba_base[1]
	var proba_A: float = proba_base[2]
	var proba_S: float = proba_base[3]

	var paliers_niveau: int = int(max(niveau_zone - 1, 0) / 5)
	var bonus_repartition: float = float(paliers_niveau) * 0.05
	var deplacement_depuis_C: float = min(bonus_repartition, proba_C - 0.1)
	if deplacement_depuis_C > 0.0:
		proba_C -= deplacement_depuis_C
		proba_B += deplacement_depuis_C * 0.5
		proba_A += deplacement_depuis_C * 0.3
		proba_S += deplacement_depuis_C * 0.2

	if chance_joueur > 0.0:
		var facteur_chance = clamp(chance_joueur, 0.0, 100.0) / 100.0
		var bonus_A: float = 0.05 * facteur_chance
		var bonus_S: float = 0.02 * facteur_chance
		var total_bonus: float = bonus_A + bonus_S

		var montant_max_deplacable: float = proba_C * 0.7 + proba_B * 0.3
		var montant_deplace: float = min(total_bonus, montant_max_deplacable)

		var pris_sur_C: float = min(proba_C, montant_deplace * 0.7)
		var pris_sur_B: float = min(proba_B, montant_deplace * 0.3)
		proba_C -= pris_sur_C
		proba_B -= pris_sur_B
		proba_A += bonus_A
		proba_S += bonus_S

	proba_C *= multiplicateur_rarete_C
	proba_B *= multiplicateur_rarete_B
	proba_A *= multiplicateur_rarete_A
	proba_S *= multiplicateur_rarete_S

	var somme_probas: float = proba_C + proba_B + proba_A + proba_S
	if somme_probas <= 0.0:
		return Loot.TypeLoot.C

	proba_C /= somme_probas
	proba_B /= somme_probas
	proba_A /= somme_probas
	proba_S /= somme_probas

	var tirage_aleatoire: float = _generateur_aleatoire.randf()
	if tirage_aleatoire < proba_C:
		return Loot.TypeLoot.C
	tirage_aleatoire -= proba_C
	if tirage_aleatoire < proba_B:
		return Loot.TypeLoot.B
	tirage_aleatoire -= proba_B
	if tirage_aleatoire < proba_A:
		return Loot.TypeLoot.A
	return Loot.TypeLoot.S

func _tirer_type_item(rarete: int) -> int:
	var poids_conso: float = 0.0
	var poids_upgrade: float = 0.0
	var poids_arme: float = 0.0

	match rarete:
		Loot.TypeLoot.C:
			poids_conso = 0.7
			poids_upgrade = 0.2
			poids_arme = 0.1
		Loot.TypeLoot.B:
			poids_conso = 0.4
			poids_upgrade = 0.4
			poids_arme = 0.2
		Loot.TypeLoot.A:
			poids_conso = 0.3
			poids_upgrade = 0.4
			poids_arme = 0.3
		Loot.TypeLoot.S:
			poids_conso = 0.1
			poids_upgrade = 0.4
			poids_arme = 0.5
		_:
			poids_conso = 1.0
			poids_upgrade = 0.0
			poids_arme = 0.0

	poids_conso *= multiplicateur_type_conso
	poids_upgrade *= multiplicateur_type_upgrade
	poids_arme *= multiplicateur_type_arme

	var somme_poids := poids_conso + poids_upgrade + poids_arme
	if somme_poids <= 0.0:
		return Loot.TypeItem.CONSO

	poids_conso /= somme_poids
	poids_upgrade /= somme_poids
	poids_arme /= somme_poids

	var tirage_aleatoire := _generateur_aleatoire.randf()
	if tirage_aleatoire < poids_conso:
		return Loot.TypeItem.CONSO
	tirage_aleatoire -= poids_conso
	if tirage_aleatoire < poids_upgrade:
		return Loot.TypeItem.UPGRADE
	return Loot.TypeItem.ARME

func _d_loot(msg: String) -> void:
	if debug_loot:
		print(msg)

func _tirer_item_id(type_item: int, rarete: int) -> StringName:
	if type_item == Loot.TypeItem.CONSO:
		var tirage_aleatoire := _generateur_aleatoire.randf()
		match rarete:
			Loot.TypeLoot.C:
				if tirage_aleatoire < 0.45:
					return &"conso_heal_full_1"
				elif tirage_aleatoire < 0.75:
					return &"conso_regen_1"
				elif tirage_aleatoire < 0.95:
					return &"conso_overheal_1"
				else:
					return &"conso_invincible_1"

			Loot.TypeLoot.B:
				if tirage_aleatoire < 0.35:
					return &"conso_heal_full_2"
				elif tirage_aleatoire < 0.65:
					return &"conso_regen_2"
				elif tirage_aleatoire < 0.85:
					return &"conso_overheal_1"
				elif tirage_aleatoire < 0.95:
					return &"conso_invincible_1"
				else:
					return &"conso_rage_1"

			Loot.TypeLoot.A:
				if tirage_aleatoire < 0.30:
					return &"conso_heal_full_3"
				elif tirage_aleatoire < 0.55:
					return &"conso_regen_3"
				elif tirage_aleatoire < 0.75:
					return &"conso_overheal_2"
				elif tirage_aleatoire < 0.90:
					return &"conso_invincible_2"
				else:
					return &"conso_rage_2"

			Loot.TypeLoot.S:
				if tirage_aleatoire < 0.25:
					return &"conso_overheal_3"
				elif tirage_aleatoire < 0.50:
					return &"conso_invincible_3"
				elif tirage_aleatoire < 0.75:
					return &"conso_rage_3"
				elif tirage_aleatoire < 0.90:
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
