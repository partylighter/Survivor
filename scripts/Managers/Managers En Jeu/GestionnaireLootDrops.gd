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
@export var tirages_bonus_par_10_progression: int = 1
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

@export_group("Loot: Tables de rareté par type d'ennemi")
@export var table_C: LootTableEnemy
@export var table_B: LootTableEnemy
@export var table_A: LootTableEnemy
@export var table_S: LootTableEnemy
@export var table_BOSS: LootTableEnemy

@export_group("Loot: Pity system")
@export var pity_seuil_A: int = 30
@export var pity_seuil_S: int = 80
@export var pity_boost_A: float = 1.8
@export var pity_boost_S: float = 2.0

var _generateur_aleatoire: RandomNumberGenerator
var _depuis_dernier_A: int = 0
var _depuis_dernier_S: int = 0


func generer_loot_pour_ennemi(
	e: Node2D,
	rng: RandomNumberGenerator,
	joueur: Node2D,
	progression_loot: float = 0.0
) -> void:
	if scene_loot == null:
		return
	if not (e is Enemy):
		return

	_generateur_aleatoire = rng

	var ennemi := e as Enemy
	var type_ennemi: int = ennemi.type_ennemi

	var progression = max(progression_loot, 0.0)
	var niveau_effectif: float = 1.0 + progression
	var chance_joueur: float = _get_player_luck(joueur)

	if debug_loot:
		print("[LootDrops] enemy=", ennemi.name,
			" type_ennemi=", type_ennemi,
			" prog=", progression_loot,
			" niveau_eff=", niveau_effectif,
			" luck=", chance_joueur,
			" tirages C=", tirages_min_type_C, "-", tirages_max_type_C,
			" B=", tirages_min_type_B, "-", tirages_max_type_B,
			" A=", tirages_min_type_A, "-", tirages_max_type_A,
			" S=", tirages_min_type_S, "-", tirages_max_type_S,
			" BOSS=", tirages_min_type_BOSS, "-", tirages_max_type_BOSS,
			" mult=", multiplicateur_tirages_global)

	var nb_loots: int = _tirer_nombre_tirages(type_ennemi, niveau_effectif)

	if debug_loot:
		print("[LootDrops] nb_loots=", nb_loots)

	if nb_loots <= 0:
		return

	for i in range(nb_loots):
		var rarete: int = _tirer_rarete(type_ennemi, niveau_effectif, chance_joueur)

		if rarete >= Loot.TypeLoot.A:
			_depuis_dernier_A = 0
		else:
			_depuis_dernier_A += 1

		if rarete >= Loot.TypeLoot.S:
			_depuis_dernier_S = 0
		else:
			_depuis_dernier_S += 1

		var table := _get_table_enemy(type_ennemi)
		if table == null:
			continue

		var pick := table.tirer_loot(
			rarete,
			_generateur_aleatoire,
			multiplicateur_type_conso,
			multiplicateur_type_upgrade,
			multiplicateur_type_arme
		)

		var type_item: int = int(pick["type_item"])
		var item_id: StringName = pick["item_id"]

		if debug_loot:
			print("[LootDrops] i=", i, " rarete=", rarete, " type_item=", type_item, " item_id=", String(item_id))

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

	

func _tirer_nombre_tirages(type_ennemi: int, niveau_effectif: float) -> int:
	var nb_min := 0
	var nb_max := 0

	match type_ennemi:
		Enemy.TypeEnnemi.C:
			nb_min = tirages_min_type_C
			nb_max = tirages_max_type_C
		Enemy.TypeEnnemi.B:
			nb_min = tirages_min_type_B
			nb_max = tirages_max_type_B
		Enemy.TypeEnnemi.A:
			nb_min = tirages_min_type_A
			nb_max = tirages_max_type_A
		Enemy.TypeEnnemi.S:
			nb_min = tirages_min_type_S
			nb_max = tirages_max_type_S
		Enemy.TypeEnnemi.BOSS:
			nb_min = tirages_min_type_BOSS
			nb_max = tirages_max_type_BOSS
		_:
			nb_min = 0
			nb_max = 1

	var bonus_progression := int(max(niveau_effectif - 1.0, 0.0) / 10.0) * tirages_bonus_par_10_progression
	nb_max += bonus_progression

	if nb_max < nb_min:
		nb_max = nb_min

	if nb_max <= nb_min:
		var nb_base := nb_min
		var nb := int(round(float(nb_base) * multiplicateur_tirages_global))
		return max(0, nb)

	var nb_brut := _generateur_aleatoire.randi_range(nb_min, nb_max)
	var nb_final := int(round(float(nb_brut) * multiplicateur_tirages_global))
	return max(0, nb_final)


func _get_table_enemy(type_ennemi: int) -> LootTableEnemy:
	match type_ennemi:
		Enemy.TypeEnnemi.C:
			return table_C
		Enemy.TypeEnnemi.B:
			return table_B
		Enemy.TypeEnnemi.A:
			return table_A
		Enemy.TypeEnnemi.S:
			return table_S
		Enemy.TypeEnnemi.BOSS:
			return table_BOSS
		_:
			return null


func _proba_rarete_base(type_ennemi: int) -> PackedFloat32Array:
	var t: LootTableEnemy = _get_table_enemy(type_ennemi)
	if t == null:
		return PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	return PackedFloat32Array([t.proba_C, t.proba_B, t.proba_A, t.proba_S])


func _get_player_luck(joueur: Node2D) -> float:
	if joueur != null and is_instance_valid(joueur) and joueur.has_method("get_luck"):
		return float(joueur.get_luck())
	return 0.0


func _tirer_rarete(type_ennemi: int, niveau_effectif: float, chance_joueur: float) -> int:
	var proba_base: PackedFloat32Array = _proba_rarete_base(type_ennemi)
	if proba_base.size() < 4:
		return Loot.TypeLoot.C

	var proba_C: float = proba_base[0]
	var proba_B: float = proba_base[1]
	var proba_A: float = proba_base[2]
	var proba_S: float = proba_base[3]

	var paliers_niveau: int = int(max(niveau_effectif - 1.0, 0.0) / 5.0)
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

	if _depuis_dernier_A >= pity_seuil_A:
		proba_A *= pity_boost_A
	if _depuis_dernier_S >= pity_seuil_S:
		proba_S *= pity_boost_S

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


func _tirer_item_id(type_ennemi: int, type_item: int, rarete: int) -> StringName:
	var table: LootTableEnemy = _get_table_enemy(type_ennemi)
	if table == null:
		return &""
	return table.tirer_item_id(type_item, rarete, _generateur_aleatoire)


func simuler_loot(type_ennemi: int, progression_loot: float, chance_joueur: float, essais: int = 10000) -> void:
	var stats_rarete := {
		Loot.TypeLoot.C: 0,
		Loot.TypeLoot.B: 0,
		Loot.TypeLoot.A: 0,
		Loot.TypeLoot.S: 0,
	}
	var stats_type := {
		Loot.TypeItem.CONSO: 0,
		Loot.TypeItem.UPGRADE: 0,
		Loot.TypeItem.ARME: 0,
	}

	_generateur_aleatoire = RandomNumberGenerator.new()
	_generateur_aleatoire.randomize()

	_depuis_dernier_A = 0
	_depuis_dernier_S = 0

	var progression = max(progression_loot, 0.0)
	var niveau_effectif: float = 1.0 + progression

	for i in range(essais):
		var rarete := _tirer_rarete(type_ennemi, niveau_effectif, chance_joueur)
		stats_rarete[rarete] += 1
		var type_item := _tirer_type_item(rarete)
		stats_type[type_item] += 1

	print("--- Simulation loot ---")
	print("Essais :", essais, " progression=", progression_loot, " niveau_eff=", niveau_effectif)
	print("Rareté : C=", stats_rarete[Loot.TypeLoot.C],
		" B=", stats_rarete[Loot.TypeLoot.B],
		" A=", stats_rarete[Loot.TypeLoot.A],
		" S=", stats_rarete[Loot.TypeLoot.S])
	print("Types : CONSO=", stats_type[Loot.TypeItem.CONSO],
		" UPGRADE=", stats_type[Loot.TypeItem.UPGRADE],
		" ARME=", stats_type[Loot.TypeItem.ARME])
