extends Node
class_name GestionDeplacementJoueur

@export_group("Deplacement")
@export var inertie_active: bool = true
@export var acceleration_px_s2: float = 9000.0
@export var deceleration_px_s2: float = 12000.0
@export var freinage_virage_mult: float = 1.65
@export var seuil_arret_px_s: float = 25.0
@export var zone_morte: float = 0.10
@export_range(0.1, 1.0, 0.01) var vitesse_cote_mult: float = 0.78
@export_range(0.1, 1.0, 0.01) var vitesse_reculons_mult: float = 0.62

@export_group("Soif")
@export var distance_par_point_soif: float = 150.0
@export var cout_soif_dash: float = 4.0

@export_group("Elan au depart")
@export var elan_depart_actif: bool = true
@export var elan_depart_impulsion_px_s: float = 120.0
@export var elan_depart_plafond_mult: float = 1.15
@export var elan_depart_vitesse_max_declenche_px_s: float = 40.0
@export var elan_depart_blocage_s: float = 0.08

@export_group("Dash")
@export var dash_multiplicateur_vitesse: float = 3.0
@export var dash_duree_s: float = 0.15
@export var dash_impulsion_depart_mult: float = 1.18
@export var dash_vitesse_fin_mult: float = 0.58
@export var dash_knockback_actif: bool = true
@export var dash_knockback_force: float = 520.0
@export var dash_knockback_rayon_px: float = 165.0
@export var dash_knockback_force_bord_mult: float = 0.45
@export var dash_autoriser_sans_direction: bool = true
@export var dash_recharge_pendant_dash: bool = false
@export var dash_afficher_infos: bool = false

var _derniere_direction: Vector2 = Vector2.RIGHT
var _avait_entree: bool = false
var _elan_blocage_restant_s: float = 0.0
var _ennemis_touches_dash: Dictionary = {}


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

	var vitesse_stats: float = stats.get_vitesse_effective()
	var vitesse_base: float = vitesse_stats
	if len_dir > 0.0:
		vitesse_base *= _calculer_multiplicateur_direction_souris(joueur, dir.normalized())
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
			if joueur is Player:
				var player_dash := joueur as Player
				if player_dash.soif != null and is_instance_valid(player_dash.soif):
					player_dash.soif.perdre_soif(cout_soif_dash)

			if not joueur.dash_infini_actif:
				joueur.dash_charges_actuelles -= 1
			joueur.dash_t_restant_s = dash_duree_s
			joueur.dash_duree_s = dash_duree_s
			joueur.dash_direction = direction_dash
			joueur.dash_timer_recup_s = 0.0
			_ennemis_touches_dash.clear()

			if dash_afficher_infos:
				print("DASH -> charges=%d / max=%d  infini=%s" % [
					joueur.dash_charges_actuelles,
					dash_max,
					str(joueur.dash_infini_actif)
				])

	var dash_actif_frame: bool = joueur.dash_t_restant_s > 0.0
	if dash_actif_frame:
		joueur.dash_t_restant_s -= dt
		var progression_dash: float = clampf(joueur.dash_t_restant_s / maxf(dash_duree_s, 0.001), 0.0, 1.0)
		var courbe_dash: float = pow(progression_dash, 0.55)
		var vitesse_dash_mult: float = lerpf(dash_vitesse_fin_mult, dash_impulsion_depart_mult, courbe_dash)
		var v_dash: float = vitesse_stats * dash_multiplicateur_vitesse * vitesse_dash_mult
		joueur.velocity = joueur.dash_direction * v_dash
	else:
		var vitesse_voulue: Vector2 = dir * vitesse_base

		if inertie_active:
			var taux: float = acceleration_px_s2 if len_dir > 0.0 else deceleration_px_s2
			if len_dir > 0.0 and joueur.velocity.length_squared() > 0.0001:
				var direction_vitesse: Vector2 = joueur.velocity.normalized()
				var opposition: float = maxf(0.0, -direction_vitesse.dot(dir.normalized()))
				taux *= lerpf(1.0, maxf(freinage_virage_mult, 1.0), opposition)
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
		joueur.velocity += (joueur as Player).tick_recul_externe(dt)
		(joueur as Player).collision_ennemis_pre(dt)

	var pos_avant: Vector2 = joueur.global_position
	joueur.move_and_slide()
	if dash_actif_frame:
		_appliquer_knockback_dash(joueur, pos_avant, joueur.global_position)
	var distance_parcourue: float = joueur.global_position.distance_to(pos_avant)

	if joueur is Player:
		var player_move := joueur as Player
		if player_move.soif != null and is_instance_valid(player_move.soif):
			var perte_soif: float = distance_parcourue / distance_par_point_soif
			player_move.soif.perdre_soif(perte_soif)

	if joueur is Player:
		(joueur as Player).collision_ennemis_post(dt)

func _calculer_multiplicateur_direction_souris(joueur: CharacterBody2D, direction_deplacement: Vector2) -> float:
	var direction_souris: Vector2 = joueur.get_global_mouse_position() - joueur.global_position
	if direction_souris.length_squared() <= 0.0001:
		return 1.0

	var alignement: float = direction_deplacement.dot(direction_souris.normalized())
	if alignement >= 0.0:
		return lerpf(vitesse_cote_mult, 1.0, alignement)
	return lerpf(vitesse_cote_mult, vitesse_reculons_mult, -alignement)

func _appliquer_knockback_dash(joueur: CharacterBody2D, segment_debut: Vector2, segment_fin: Vector2) -> void:
	if not dash_knockback_actif:
		return
	if joueur.dash_direction.length_squared() <= 0.0001:
		return

	var direction_dash: Vector2 = joueur.dash_direction.normalized()
	var rayon_base: float = maxf(dash_knockback_rayon_px, 0.0)
	var force: float = maxf(dash_knockback_force, 0.0)
	if rayon_base <= 0.0 or force <= 0.0:
		return

	for n in joueur.get_tree().get_nodes_in_group("enemy"):
		var ennemi := n as Enemy
		if ennemi == null or not is_instance_valid(ennemi):
			continue
		if _ennemis_touches_dash.has(ennemi.get_instance_id()):
			continue
		if not ennemi.is_alive():
			continue

		var point_impact: Vector2 = _point_plus_proche_sur_segment(
			ennemi.global_position,
			segment_debut,
			segment_fin
		)
		var delta: Vector2 = ennemi.global_position - point_impact
		var rayon_total: float = rayon_base + ennemi.hit_radius()
		if delta.length_squared() > rayon_total * rayon_total:
			continue

		var distance: float = sqrt(maxf(delta.length_squared(), 0.0001))
		var direction_recul: Vector2 = delta / distance
		if direction_recul.length_squared() <= 0.0001:
			direction_recul = ennemi.global_position - joueur.global_position
			if direction_recul.length_squared() <= 0.0001:
				direction_recul = direction_dash
			else:
				direction_recul = direction_recul.normalized()

		var resistance_dash: float = maxf(ennemi.resistance_knockback_dash, 0.0)
		var recul_dash_mult: float = maxf(ennemi.recul_knockback_dash_mult, 0.0)
		var t_distance: float = clampf(distance / maxf(rayon_total, 0.001), 0.0, 1.0)
		var multiplicateur_distance: float = lerpf(1.0, maxf(dash_knockback_force_bord_mult, 0.0), t_distance)
		var force_finale: float = force * multiplicateur_distance * recul_dash_mult * (1.0 - resistance_dash)
		if force_finale <= 0.0:
			_ennemis_touches_dash[ennemi.get_instance_id()] = true
			continue

		ennemi.appliquer_recul_dash(direction_recul, force_finale)
		_ennemis_touches_dash[ennemi.get_instance_id()] = true

func _point_plus_proche_sur_segment(point: Vector2, segment_debut: Vector2, segment_fin: Vector2) -> Vector2:
	var segment: Vector2 = segment_fin - segment_debut
	var longueur2: float = segment.length_squared()
	if longueur2 <= 0.0001:
		return segment_fin
	var t: float = clampf((point - segment_debut).dot(segment) / longueur2, 0.0, 1.0)
	return segment_debut + segment * t
