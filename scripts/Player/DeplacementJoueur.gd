extends Node
class_name GestionDeplacementJoueur

@export_group("Deplacement")
@export var inertie_active: bool = true
@export var acceleration_px_s2: float = 9000.0
@export var deceleration_px_s2: float = 12000.0
@export var seuil_arret_px_s: float = 25.0
@export var zone_morte: float = 0.10

@export_group("Elan au depart")
@export var elan_depart_actif: bool = true
@export var elan_depart_impulsion_px_s: float = 120.0
@export var elan_depart_plafond_mult: float = 1.15
@export var elan_depart_vitesse_max_declenche_px_s: float = 40.0
@export var elan_depart_blocage_s: float = 0.08

@export_group("Dash")
@export var dash_multiplicateur_vitesse: float = 3.0
@export var dash_duree_s: float = 0.15
@export var dash_autoriser_sans_direction: bool = true
@export var dash_recharge_pendant_dash: bool = false
@export var dash_afficher_infos: bool = false

var _derniere_direction: Vector2 = Vector2.RIGHT
var _avait_entree: bool = false
var _elan_blocage_restant_s: float = 0.0


func traiter(joueur: CharacterBody2D, stats: StatsJoueur, dt: float) -> void:
	if _elan_blocage_restant_s > 0.0:
		_elan_blocage_restant_s = maxf(0.0, _elan_blocage_restant_s - dt)

	var entree_precedente: bool = _avait_entree

	var dir: Vector2 = Input.get_vector("gauche", "droite", "haut", "bas")
	var len_dir: float = dir.length()

	if len_dir < zone_morte:
		dir = Vector2.ZERO
		len_dir = 0.0
	else:
		_derniere_direction = dir.normalized()

	_avait_entree = len_dir > 0.0

	var vitesse_base: float = stats.get_vitesse_effective()
	var dash_max: int = stats.get_dash_max_effectif()
	var dash_cooldown_s: float = stats.get_dash_cooldown_effectif()
	joueur.dash_cooldown_s = dash_cooldown_s

	if joueur.dash_charges_actuelles > dash_max:
		joueur.dash_charges_actuelles = dash_max

	var dash_ok: bool = true
	if joueur is Player:
		dash_ok = (joueur as Player).dash_autorise

	var dash_appuye: bool = dash_ok and Input.is_action_just_pressed("dash")
	var dash_possible: bool = dash_ok and joueur.dash_t_restant_s <= 0.0 and (joueur.dash_infini_actif or joueur.dash_charges_actuelles > 0)

	if dash_appuye and dash_possible:
		var direction_dash: Vector2 = Vector2.ZERO
		if len_dir > 0.0:
			direction_dash = dir.normalized()
		elif dash_autoriser_sans_direction:
			direction_dash = _derniere_direction

		if direction_dash.length_squared() > 0.0001:
			if not joueur.dash_infini_actif:
				joueur.dash_charges_actuelles -= 1
			joueur.dash_t_restant_s = dash_duree_s
			joueur.dash_direction = direction_dash
			joueur.dash_timer_recup_s = 0.0

			if dash_afficher_infos:
				print("DASH -> charges=%d / max=%d  infini=%s" % [
					joueur.dash_charges_actuelles,
					dash_max,
					str(joueur.dash_infini_actif)
				])

	if joueur.dash_t_restant_s > 0.0:
		joueur.dash_t_restant_s -= dt
		var v_dash: float = vitesse_base * dash_multiplicateur_vitesse
		joueur.velocity = joueur.dash_direction * v_dash
	else:
		var vitesse_voulue: Vector2 = dir * vitesse_base

		if inertie_active:
			var taux: float = acceleration_px_s2 if len_dir > 0.0 else deceleration_px_s2
			joueur.velocity = joueur.velocity.move_toward(vitesse_voulue, taux * dt)
			if len_dir <= 0.0 and joueur.velocity.length() < seuil_arret_px_s:
				joueur.velocity = Vector2.ZERO
		else:
			joueur.velocity = vitesse_voulue

		if elan_depart_actif and len_dir > 0.0 and not entree_precedente and _elan_blocage_restant_s <= 0.0:
			if joueur.velocity.length() <= elan_depart_vitesse_max_declenche_px_s:
				joueur.velocity += dir.normalized() * elan_depart_impulsion_px_s
				var plafond: float = vitesse_base * elan_depart_plafond_mult
				if joueur.velocity.length() > plafond:
					joueur.velocity = joueur.velocity.normalized() * plafond
				_elan_blocage_restant_s = elan_depart_blocage_s

	var autoriser_recharge: bool = dash_recharge_pendant_dash or joueur.dash_t_restant_s <= 0.0
	if autoriser_recharge and not joueur.dash_infini_actif and joueur.dash_charges_actuelles < dash_max:
		joueur.dash_timer_recup_s += dt
		if joueur.dash_timer_recup_s >= dash_cooldown_s:
			joueur.dash_timer_recup_s -= dash_cooldown_s
			joueur.dash_charges_actuelles += 1
			if joueur.dash_charges_actuelles > dash_max:
				joueur.dash_charges_actuelles = dash_max

	if joueur is Player:
		(joueur as Player).collision_ennemis_pre(dt)

	joueur.move_and_slide()

	if joueur is Player:
		(joueur as Player).collision_ennemis_post(dt)
