extends Node
class_name GestionnaireLoot

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

var joueur: Player
var stats: StatsJoueur
var sante: Sante
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


func _ready() -> void:
	joueur = get_parent() as Player
	set_process(true)


func _ensure_refs() -> void:
	if joueur == null:
		joueur = get_parent() as Player
	if joueur != null and stats == null:
		stats = joueur.stats
	if joueur != null and sante == null:
		sante = joueur.sante
		if sante != null and not sante.damaged.is_connected(_on_player_damaged):
			sante.damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	_ensure_refs()

	if regen_time_left > 0.0 and sante and not sante.is_dead():
		regen_time_left -= delta
		if regen_time_left < 0.0:
			regen_time_left = 0.0
		var to_heal: float = regen_heal_per_sec * delta
		regen_accum += to_heal
		var heal_int: int = int(regen_accum)
		if heal_int > 0 and joueur:
			joueur.soigner(heal_int)
			regen_accum -= float(heal_int)

	if invincible_time_left > 0.0:
		invincible_time_left -= delta
		if invincible_time_left < 0.0:
			invincible_time_left = 0.0

	if rage_time_left > 0.0:
		rage_time_left -= delta
		if rage_time_left <= 0.0:
			_fin_rage()


func _on_player_damaged(amount: int, _source: Node) -> void:
	_ensure_refs()
	if sante == null:
		return
	if invincible_time_left > 0.0 and amount > 0:
		sante.heal(amount)


func _d_loot(msg: String) -> void:
	if debug_loot:
		print(msg)


func _enregistrer_loot(identifiant: StringName, quantite: int) -> void:
	if String(identifiant) == "":
		return
	var actuel: int = stats_loot.get(identifiant, 0)
	stats_loot[identifiant] = actuel + quantite


func get_stats_loot() -> Dictionary:
	return stats_loot.duplicate()


func on_loot_collecte(payload: Dictionary) -> void:
	_ensure_refs()
	if joueur == null:
		return

	var type_item: int = payload.get("type_item", Loot.TypeItem.CONSO)
	var rarete: int = payload.get("type_loot", Loot.TypeLoot.C)
	var identifiant: StringName = payload.get("id", &"")
	var quantite: int = payload.get("quantite", 1)
	var scene_contenu: PackedScene = payload.get("scene", null)

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
	if arme == null:
		return
	arme.global_position = joueur.global_position + Vector2(24, 0)
	get_tree().current_scene.add_child(arme)


func _appliquer_consommable(identifiant: StringName, quantite: int) -> void:
	var id := String(identifiant)
	_d_loot("[Loot] consommable ramassé : %s x%d" % [id, quantite])

	match id:
		"conso_heal":
			if sante == null or joueur == null:
				return
			var heal_par_item: int = int(float(sante.max_pv) * float(conso_heal_amount) / 100.0)
			var total_heal: int = heal_par_item * quantite
			var manque: int = maxi(0, int(ceil(float(sante.max_pv) - sante.pv)))
			var heal_reel: int = mini(total_heal, manque)
			if heal_reel > 0:
				joueur.soigner(heal_reel)

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
		print("[Overheal] ignoré (sante=%s amount=%.1f)" % [str(sante), amount])
		return

	var before_pv: float = sante.pv
	var before_over: float = sante.get_overheal()

	sante.set_full_pv()

	var add_over: float = amount * float(quantite)
	sante.add_overheal(add_over)

	var after_pv: float = sante.pv
	var after_over: float = sante.get_overheal()

	print("[Overheal] +%.1f (pv %.1f -> %.1f, over %.1f -> %.1f)" % [
		add_over, before_pv, after_pv, before_over, after_over
	])


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
		_d_loot("[RAGE] vitesse_effective=%f dash_max=%d infini=%s" % [
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


func _appliquer_amelioration(identifiant: StringName, quantite: int) -> void:
	_d_loot("[Loot] upgrade SANS EFFET : %s x%d" % [str(identifiant), quantite])


func _debloquer_arme_par_id(identifiant: StringName, rarete: int, quantite: int) -> void:
	_d_loot("[Loot] arme logique : %s rarete : %d x%d" % [str(identifiant), rarete, quantite])
