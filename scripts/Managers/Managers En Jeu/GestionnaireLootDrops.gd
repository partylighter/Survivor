extends Node
class_name GestionnaireLootDrops

@export var scene_loot: PackedScene
@export var debug_loot: bool = false

@export_group("Spawn anti-spike")
@export var budget_spawn_par_frame: int = 11
@export var offset_spawn_px: float = 16.0
@export var pool_taille: int = 250
@export var parent_loot_path: NodePath

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

var _pool: Array[Loot] = []
var _file_spawn: Array[Dictionary] = []
var _file_tete: int = 0

var _generateur_aleatoire: RandomNumberGenerator = null
var _depuis_dernier_A: int = 0
var _depuis_dernier_S: int = 0

var _parent_loots: Node = null

func _ready() -> void:
	_parent_loots = _get_parent_loots()
	_precharger_pool()
	set_process(true)

func _process(_dt: float) -> void:
	if _file_tete >= _file_spawn.size():
		if not _file_spawn.is_empty():
			_file_spawn.clear()
		_file_tete = 0
		return

	if _pool.is_empty():
		return

	var restant: int = _file_spawn.size() - _file_tete
	if restant <= 0:
		return

	var quota: int = budget_spawn_par_frame if budget_spawn_par_frame > 0 else restant
	var n: int = mini(quota, restant)

	for _i: int in range(n):
		if _pool.is_empty():
			return
		var req: Dictionary = _file_spawn[_file_tete]
		_file_tete += 1
		var loot: Loot = _pool.pop_back()
		loot.activer_depuis_pool(req, _parent_loots)

	if _file_tete >= _file_spawn.size():
		_file_spawn.clear()
		_file_tete = 0

func retourner_loot(l: Loot) -> void:
	if l == null:
		return
	if _pool.has(l):
		return
	_pool.append(l)

func _precharger_pool() -> void:
	if scene_loot == null:
		return
	if _parent_loots == null:
		_parent_loots = get_tree().current_scene

	var n: int = maxi(pool_taille, 0)
	for i: int in range(n):
		var loot: Loot = scene_loot.instantiate() as Loot
		if loot == null:
			continue
		loot.preparer_pour_pool(self)
		loot.global_position = Vector2(1000000.0 + float(i), 1000000.0)
		_parent_loots.add_child(loot)
		_pool.append(loot)

func _get_parent_loots() -> Node:
	if parent_loot_path != NodePath():
		var n: Node = get_node_or_null(parent_loot_path)
		if n != null:
			return n
	return get_tree().current_scene

func demander_drops(
	type_ennemi: int,
	position_mort: Vector2,
	rng: RandomNumberGenerator,
	joueur: Node2D,
	progression_loot: float = 0.0
) -> void:
	if scene_loot == null:
		return
	if rng == null:
		return

	_generateur_aleatoire = rng

	var progression: float = maxf(progression_loot, 0.0)
	var niveau_effectif: float = 1.0 + progression
	var chance_joueur: float = _get_player_luck(joueur)

	var nb_loots: int = _tirer_nombre_tirages(type_ennemi, niveau_effectif)
	if nb_loots <= 0:
		return

	var table: LootTableEnemy = _get_table_enemy(type_ennemi)
	if table == null:
		return

	for _i: int in range(nb_loots):
		var rarete: int = _tirer_rarete(type_ennemi, niveau_effectif, chance_joueur)

		if rarete >= Loot.TypeLoot.A:
			_depuis_dernier_A = 0
		else:
			_depuis_dernier_A += 1

		if rarete >= Loot.TypeLoot.S:
			_depuis_dernier_S = 0
		else:
			_depuis_dernier_S += 1

		var pick: Dictionary = table.tirer_loot(
			rarete,
			_generateur_aleatoire,
			multiplicateur_type_conso,
			multiplicateur_type_upgrade,
			multiplicateur_type_arme
		)

		var type_item: int = int(pick.get("type_item", Loot.TypeItem.CONSO))
		var item_id: StringName = pick.get("item_id", &"")

		if String(item_id) == "":
			continue

		var ox: float = _generateur_aleatoire.randf_range(-offset_spawn_px, offset_spawn_px)
		var oy: float = _generateur_aleatoire.randf_range(-offset_spawn_px, offset_spawn_px)

		_file_spawn.append({
			"pos": position_mort + Vector2(ox, oy),
			"rarete": rarete,
			"type_item": type_item,
			"item_id": item_id,
			"quantite": 1,
			"joueur": joueur
		})

func _tirer_nombre_tirages(type_ennemi: int, niveau_effectif: float) -> int:
	var nb_min: int = 0
	var nb_max: int = 0

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

	var bonus_progression: int = int(maxf(niveau_effectif - 1.0, 0.0) / 10.0) * tirages_bonus_par_10_progression
	nb_max += bonus_progression
	if nb_max < nb_min:
		nb_max = nb_min

	var nb_brut: int = nb_min if nb_max <= nb_min else _generateur_aleatoire.randi_range(nb_min, nb_max)
	var nb_final: int = int(round(float(nb_brut) * multiplicateur_tirages_global))
	return maxi(0, nb_final)

func _get_table_enemy(type_ennemi: int) -> LootTableEnemy:
	match type_ennemi:
		Enemy.TypeEnnemi.C: return table_C
		Enemy.TypeEnnemi.B: return table_B
		Enemy.TypeEnnemi.A: return table_A
		Enemy.TypeEnnemi.S: return table_S
		Enemy.TypeEnnemi.BOSS: return table_BOSS
		_: return null

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

	var paliers_niveau: int = int(maxf(niveau_effectif - 1.0, 0.0) / 5.0)
	var bonus_repartition: float = float(paliers_niveau) * 0.05
	var deplacement_depuis_C: float = minf(bonus_repartition, proba_C - 0.1)

	if deplacement_depuis_C > 0.0:
		proba_C -= deplacement_depuis_C
		proba_B += deplacement_depuis_C * 0.5
		proba_A += deplacement_depuis_C * 0.3
		proba_S += deplacement_depuis_C * 0.2

	if chance_joueur > 0.0:
		var facteur_chance: float = clampf(chance_joueur, 0.0, 100.0) / 100.0
		var bonus_A: float = 0.05 * facteur_chance
		var bonus_S: float = 0.02 * facteur_chance
		var total_bonus: float = bonus_A + bonus_S

		var montant_max_deplacable: float = proba_C * 0.7 + proba_B * 0.3
		var montant_deplace: float = minf(total_bonus, montant_max_deplacable)

		var pris_sur_C: float = minf(proba_C, montant_deplace * 0.7)
		var pris_sur_B: float = minf(proba_B, montant_deplace * 0.3)

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

	var somme: float = proba_C + proba_B + proba_A + proba_S
	if somme <= 0.0:
		return Loot.TypeLoot.C

	proba_C /= somme
	proba_B /= somme
	proba_A /= somme
	proba_S /= somme

	var r: float = _generateur_aleatoire.randf()
	if r < proba_C:
		return Loot.TypeLoot.C
	r -= proba_C
	if r < proba_B:
		return Loot.TypeLoot.B
	r -= proba_B
	if r < proba_A:
		return Loot.TypeLoot.A
	return Loot.TypeLoot.S
