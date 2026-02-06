extends Node
class_name GestionnaireLoot

signal carburant_stock_change(stocke: float)
signal loot_change()

const ID_UP_CARB_1: StringName = &"upgrade_carburant_1"
const ID_UP_CARB_2: StringName = &"upgrade_carburant_2"
const ID_UP_CARB_3: StringName = &"upgrade_carburant_3"
const ID_CARB_1: StringName = &"carburant_1"
const ID_CARB_2: StringName = &"carburant_2"
const ID_CARB_3: StringName = &"carburant_3"

@export var debug_loot: bool = false

@export_group("Conso: Heal simple")
@export_range(0, 200, 5) var conso_heal_amount: int = 100

@export_group("Conso: Regen")
@export var conso_regen_1_duree: float = 4.0
@export var conso_regen_1_total: float = 30.0
@export var conso_regen_2_duree: float = 5.0
@export var conso_regen_2_total: float = 60.0
@export var conso_regen_3_duree: float = 6.0
@export var conso_regen_3_total: float = 100.0

@export_group("Conso: Overheal")
@export var conso_overheal_1_amount: float = 20.0
@export var conso_overheal_2_amount: float = 40.0
@export var conso_overheal_3_amount: float = 80.0

@export_group("Conso: Invincibilité")
@export var conso_invincible_1_duree: float = 2.0
@export var conso_invincible_2_duree: float = 3.5
@export var conso_invincible_3_duree: float = 5.0

@export_group("Conso: Rage 1")
@export var conso_rage_1_duree: float = 10.0
@export var conso_rage_1_speed_bonus: float = 1100.0
@export var conso_rage_1_chance_bonus: float = 0.0
@export var conso_rage_1_dash_bonus: int = 1
@export var conso_rage_1_dash_infini: bool = false

@export_group("Conso: Rage 2")
@export var conso_rage_2_duree: float = 16.0
@export var conso_rage_2_speed_bonus: float = 1180.0
@export var conso_rage_2_chance_bonus: float = 0.0
@export var conso_rage_2_dash_bonus: int = 2
@export var conso_rage_2_dash_infini: bool = false

@export_group("Conso: Rage 3")
@export var conso_rage_3_duree: float = 18.0
@export var conso_rage_3_speed_bonus: float = 1260.0
@export var conso_rage_3_chance_bonus: float = 0.0
@export var conso_rage_3_dash_bonus: int = 3
@export var conso_rage_3_dash_infini: bool = true

@export_group("Upgrade: Carburant")
@export var carburant_par_item_1: float = 12.0
@export var carburant_par_item_2: float = 24.0
@export var carburant_par_item_3: float = 40.0

var carburant_stocke: float = 0.0
var _vehicule_actuel: Node = null

var joueur: Player = null
var stats: StatsJoueur = null
var sante: Sante = null

var stats_loot: Dictionary = {}

var regen_time_left: float = 0.0
var regen_heal_per_sec: float = 0.0
var regen_accum: float = 0.0

var invincible_time_left: float = 0.0

var rage_time_left: float = 0.0
var rage_speed_bonus_add: float = 0.0
var rage_chance_bonus_add: float = 0.0
var rage_dash_bonus_add: int = 0
var rage_dash_infini: bool = false

var _nom_par_id: Dictionary = {}

func _ready() -> void:
	add_to_group("gestionnaire_loot")
	joueur = get_parent() as Player
	#_debug_remplir_loot_test()
	set_process(true)

func _exit_tree() -> void:
	remove_from_group(&"gestionnaire_loot")

#func _debug_remplir_loot_test() -> void:
	#stats_loot[&"upgrade_test_degats"] = 3 # OK car "upgrade_" commence bien par "upgrade_"
	#stats_loot[&"upg_test_vitesse"] = 1    # OK car "upg_" commence bien par "upg_"
	#_nom_par_id[&"upgrade_test_degats"] = "Upgrade dégâts"
	#_nom_par_id[&"upg_test_vitesse"] = "Upg vitesse"

func _process(delta: float) -> void:
	_ensure_refs()
	_tick_regen(delta)
	_tick_invincible(delta)
	_tick_rage(delta)

func get_quantite_loot(id_item: StringName) -> int:
	return int(stats_loot.get(id_item, 0))

func consommer_loot(id_item: StringName, quantite: int) -> int:
	var q_demande: int = maxi(quantite, 0)
	if q_demande <= 0:
		return 0

	var q_dispo: int = int(stats_loot.get(id_item, 0))
	if q_dispo <= 0:
		return 0

	var q_pris: int = mini(q_dispo, q_demande)
	var q_reste: int = q_dispo - q_pris

	if q_reste <= 0:
		stats_loot.erase(id_item)
	else:
		stats_loot[id_item] = q_reste

	if debug_loot:
		print("[Loot] consommer_loot id=", String(id_item),
			" pris=", q_pris, " reste=", int(stats_loot.get(id_item, 0)))

	emit_signal("loot_change")
	return q_pris

func _ensure_refs() -> void:
	if joueur == null or not is_instance_valid(joueur):
		joueur = get_parent() as Player

	if joueur != null and (stats == null or not is_instance_valid(stats)):
		stats = joueur.stats
	if joueur != null and (sante == null or not is_instance_valid(sante)):
		sante = joueur.sante
		if sante != null and not sante.damaged.is_connected(_on_player_damaged):
			sante.damaged.connect(_on_player_damaged)

func get_nom_affiche_pour_id(id_any) -> String:
	var sid := StringName(String(id_any))
	if _nom_par_id.has(sid):
		return String(_nom_par_id[sid])
	return ""

func _d_loot(msg: String) -> void:
	if debug_loot:
		print(msg)

func _enregistrer_loot(identifiant: StringName, quantite: int) -> void:
	if String(identifiant) == "":
		return
	stats_loot[identifiant] = int(stats_loot.get(identifiant, 0)) + quantite
	emit_signal("loot_change")

func get_stats_loot() -> Dictionary:
	return stats_loot.duplicate()

func get_carburant_stocke() -> float:
	return carburant_stocke

func on_loot_collecte(payload: Dictionary) -> void:
	_ensure_refs()
	if joueur == null:
		return

	var type_item: int = payload.get("type_item", Loot.TypeItem.CONSO)
	var rarete: int = payload.get("type_loot", Loot.TypeLoot.C)
	var identifiant: StringName = payload.get("id", payload.get("item_id", &""))
	var quantite: int = payload.get("quantite", 1)
	var scene_contenu: PackedScene = payload.get("scene", null)

	var nom := String(payload.get("nom_affiche", "")).strip_edges()
	if nom != "":
		_nom_par_id[identifiant] = nom

	_enregistrer_loot(identifiant, quantite)

	match type_item:
		Loot.TypeItem.CONSO:
			_appliquer_consommable(identifiant, quantite)
		Loot.TypeItem.UPGRADE:
			_appliquer_amelioration(identifiant, quantite)
		Loot.TypeItem.ARME:
			if scene_contenu:
				_generer_arme_au_sol(scene_contenu)
			else:
				_debloquer_arme_par_id(identifiant, rarete, quantite)

func _generer_arme_au_sol(scene_src: PackedScene) -> void:
	var arme := scene_src.instantiate() as ArmeBase
	if arme == null or joueur == null:
		return
	arme.global_position = joueur.global_position + Vector2(24, 0)
	get_tree().current_scene.add_child(arme)

func _appliquer_consommable(identifiant: StringName, quantite: int) -> void:
	var id := String(identifiant)
	_d_loot("[Loot] consommable : %s x%d" % [id, quantite])

	match id:
		"conso_heal":
			_conso_heal(quantite)

		"conso_overheal_1":
			_conso_overheal(quantite, conso_overheal_1_amount)
		"conso_overheal_2":
			_conso_overheal(quantite, conso_overheal_2_amount)
		"conso_overheal_3":
			_conso_overheal(quantite, conso_overheal_3_amount)

		"conso_regen_1":
			_conso_regen(quantite, conso_regen_1_duree, conso_regen_1_total)
		"conso_regen_2":
			_conso_regen(quantite, conso_regen_2_duree, conso_regen_2_total)
		"conso_regen_3":
			_conso_regen(quantite, conso_regen_3_duree, conso_regen_3_total)

		"conso_invincible_1":
			_conso_invincibilite(quantite, conso_invincible_1_duree)
		"conso_invincible_2":
			_conso_invincibilite(quantite, conso_invincible_2_duree)
		"conso_invincible_3":
			_conso_invincibilite(quantite, conso_invincible_3_duree)

		"conso_rage_1":
			_conso_rage(quantite, conso_rage_1_duree, conso_rage_1_speed_bonus, conso_rage_1_chance_bonus, conso_rage_1_dash_bonus, conso_rage_1_dash_infini)
		"conso_rage_2":
			_conso_rage(quantite, conso_rage_2_duree, conso_rage_2_speed_bonus, conso_rage_2_chance_bonus, conso_rage_2_dash_bonus, conso_rage_2_dash_infini)
		"conso_rage_3":
			_conso_rage(quantite, conso_rage_3_duree, conso_rage_3_speed_bonus, conso_rage_3_chance_bonus, conso_rage_3_dash_bonus, conso_rage_3_dash_infini)

		_:
			_d_loot("[Loot] consommable inconnu : %s x%d" % [id, quantite])

func _conso_heal(quantite: int) -> void:
	_ensure_refs()
	if sante == null or joueur == null:
		return
	var heal_par_item: int = int(float(sante.max_pv) * float(conso_heal_amount) / 100.0)
	var total_heal: int = heal_par_item * quantite
	var manque: int = maxi(0, int(ceil(float(sante.max_pv) - sante.pv)))
	var heal_reel: int = mini(total_heal, manque)
	if heal_reel > 0:
		joueur.soigner(heal_reel)

func _conso_regen(quantite: int, duree: float, total_heal: float) -> void:
	_ensure_refs()
	if sante == null or duree <= 0.0 or total_heal <= 0.0:
		return
	var heal_total := total_heal * float(quantite)
	regen_time_left = duree
	regen_heal_per_sec = heal_total / duree
	regen_accum = 0.0

func _conso_overheal(quantite: int, amount: float) -> void:
	_ensure_refs()
	if sante == null or amount <= 0.0:
		return
	sante.set_full_pv()
	sante.add_overheal(amount * float(quantite))

func _conso_invincibilite(quantite: int, duree: float) -> void:
	if duree <= 0.0:
		return
	var total := duree * float(quantite)
	if invincible_time_left < total:
		invincible_time_left = total

func _conso_rage(quantite: int, duree: float, speed_bonus: float, chance_bonus: float, dash_bonus: int, dash_infini: bool) -> void:
	_ensure_refs()
	if stats == null or duree <= 0.0:
		return

	var d := duree * float(quantite)
	var s_bonus := speed_bonus * float(quantite)
	var c_bonus := chance_bonus * float(quantite)
	var dash_b := dash_bonus * quantite

	if rage_time_left <= 0.0:
		rage_time_left = d
		rage_speed_bonus_add = s_bonus
		rage_chance_bonus_add = c_bonus
		rage_dash_bonus_add = dash_b
		rage_dash_infini = dash_infini

		if rage_speed_bonus_add != 0.0:
			stats.ajouter_vitesse_add(rage_speed_bonus_add)
		if rage_chance_bonus_add != 0.0:
			stats.ajouter_chance(rage_chance_bonus_add)
		if rage_dash_bonus_add != 0:
			stats.ajouter_dash_max_add(rage_dash_bonus_add)
		if dash_infini and joueur and joueur.has_method("set_dash_infini"):
			joueur.set_dash_infini(true)

		if joueur and stats:
			joueur.dash_charges_actuelles = stats.get_dash_max_effectif()
	else:
		if d > rage_time_left:
			rage_time_left = d

		if s_bonus > rage_speed_bonus_add:
			var diff_s := s_bonus - rage_speed_bonus_add
			rage_speed_bonus_add = s_bonus
			stats.ajouter_vitesse_add(diff_s)

		if c_bonus > rage_chance_bonus_add:
			var diff_c := c_bonus - rage_chance_bonus_add
			rage_chance_bonus_add = c_bonus
			stats.ajouter_chance(diff_c)

		if dash_b > rage_dash_bonus_add:
			var diff_dash := dash_b - rage_dash_bonus_add
			rage_dash_bonus_add = dash_b
			stats.ajouter_dash_max_add(diff_dash)

		if dash_infini and not rage_dash_infini:
			rage_dash_infini = true
			if joueur and joueur.has_method("set_dash_infini"):
				joueur.set_dash_infini(true)

	if debug_loot and stats:
		_d_loot("[RAGE] vitesse=%f dash_max=%d infini=%s" % [
			stats.get_vitesse_effective(),
			stats.get_dash_max_effectif(),
			str(rage_dash_infini)
		])

func _fin_rage() -> void:
	_ensure_refs()
	if stats:
		if rage_speed_bonus_add != 0.0:
			stats.ajouter_vitesse_add(-rage_speed_bonus_add)
		if rage_chance_bonus_add != 0.0:
			stats.ajouter_chance(-rage_chance_bonus_add)
		if rage_dash_bonus_add != 0:
			stats.ajouter_dash_max_add(-rage_dash_bonus_add)

	if joueur and joueur.has_method("set_dash_infini") and rage_dash_infini:
		joueur.set_dash_infini(false)

	rage_speed_bonus_add = 0.0
	rage_chance_bonus_add = 0.0
	rage_dash_bonus_add = 0
	rage_dash_infini = false
	rage_time_left = 0.0

func _tick_regen(dt: float) -> void:
	if regen_time_left <= 0.0 or sante == null or sante.is_dead():
		return
	regen_time_left = maxf(0.0, regen_time_left - dt)
	var to_heal: float = regen_heal_per_sec * dt
	regen_accum += to_heal
	var heal_int: int = int(regen_accum)
	if heal_int > 0 and joueur != null:
		joueur.soigner(heal_int)
		regen_accum -= float(heal_int)

func _tick_invincible(dt: float) -> void:
	if invincible_time_left <= 0.0:
		return
	invincible_time_left = maxf(0.0, invincible_time_left - dt)

func _tick_rage(dt: float) -> void:
	if rage_time_left <= 0.0:
		return
	rage_time_left -= dt
	if rage_time_left <= 0.0:
		_fin_rage()

func _on_player_damaged(amount: int, _source: Node) -> void:
	_ensure_refs()
	if sante == null:
		return
	if invincible_time_left > 0.0 and amount > 0:
		sante.heal(amount)

func _carburant_par_item(niveau: int) -> float:
	match niveau:
		1: return carburant_par_item_1
		2: return carburant_par_item_2
		3: return carburant_par_item_3
		_: return carburant_par_item_1

func ajouter_carburant_stock(niveau: int, quantite: int) -> void:
	var q: int = maxi(quantite, 0)
	if q <= 0:
		return
	var add: float = _carburant_par_item(niveau) * float(q)
	if add <= 0.0:
		return
	carburant_stocke += add
	emit_signal("carburant_stock_change", carburant_stocke)
	_d_loot("[Carburant] niveau=%d +%.1f (x%d) -> stock=%.1f" % [niveau, add, q, carburant_stocke])

	if _vehicule_actuel != null and is_instance_valid(_vehicule_actuel):
		transferer_carburant_vers_vehicule(_vehicule_actuel)
	elif _vehicule_actuel != null:
		_vehicule_actuel = null

func _trouver_carburant_base(vehicule: Node) -> CarburantBase:
	if vehicule == null or not is_instance_valid(vehicule):
		return null
	if vehicule is CarburantBase:
		return vehicule as CarburantBase

	var arr: Array = vehicule.find_children("*", "CarburantBase", true, false)
	for n in arr:
		if n is CarburantBase:
			return n as CarburantBase
	return null

func transferer_carburant_vers_vehicule(vehicule: Node) -> void:
	if carburant_stocke <= 0.0:
		return

	var carb: CarburantBase = _trouver_carburant_base(vehicule)
	if carb == null:
		_d_loot("[Carburant] pas de CarburantBase sur le véhicule")
		return
	if carb.stats == null:
		_d_loot("[Carburant] CarburantBase.stats null")
		return

	var max_res: float = maxf(carb.stats.reserve_energie_max, 0.0)
	var dispo: float = maxf(max_res - carb.reserve, 0.0)
	if dispo <= 0.0:
		_d_loot("[Carburant] réservoir plein (reserve=%.1f/%.1f)" % [carb.reserve, max_res])
		return

	var send: float = minf(carburant_stocke, dispo)
	if send <= 0.0:
		return

	carb.ajouter(send)
	carburant_stocke = maxf(0.0, carburant_stocke - send)
	emit_signal("carburant_stock_change", carburant_stocke)
	_d_loot("[Carburant] transfert %.1f -> stock=%.1f (reservoir=%.1f/%.1f)" % [send, carburant_stocke, carb.reserve, max_res])

func on_entree_vehicule(vehicule: Node) -> void:
	_vehicule_actuel = vehicule
	transferer_carburant_vers_vehicule(vehicule)

func on_sortie_vehicule() -> void:
	_vehicule_actuel = null

func _appliquer_amelioration(identifiant: StringName, quantite: int) -> void:
	match identifiant:
		ID_UP_CARB_1, ID_CARB_1:
			ajouter_carburant_stock(1, quantite)
		ID_UP_CARB_2, ID_CARB_2:
			ajouter_carburant_stock(2, quantite)
		ID_UP_CARB_3, ID_CARB_3:
			ajouter_carburant_stock(3, quantite)
		_:
			pass

func _debloquer_arme_par_id(identifiant: StringName, rarete: int, quantite: int) -> void:
	_d_loot("[Loot] arme logique : %s rarete=%d x%d" % [str(identifiant), rarete, quantite])
