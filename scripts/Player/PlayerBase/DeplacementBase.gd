extends Node
class_name DeplacementBase

@export_group("Vitesses")
@export var vitesse_max_avant_px_s: float = 1800.0
@export var vitesse_max_arriere_px_s: float = 1100.0

@export_group("Acceleration / Frein")
@export var accel_avant_px_s2: float = 5200.0
@export var accel_arriere_px_s2: float = 4200.0
@export var frein_px_s2: float = 9000.0
@export var frein_moteur_px_s2: float = 2600.0
@export var friction_roulement_px_s2: float = 650.0

@export_group("Direction")
@export var vitesse_rotation_rad_s: float = 4.4
@export var steer_smooth_in: float = 18.0
@export var steer_smooth_out: float = 22.0
@export var steer_low_speed_mult: float = 1.25
@export var steer_high_speed_mult: float = 0.55
@export var steer_speed_ref_px_s: float = 1400.0

@export_group("Grip / Glisse")
@export var grip_lateral_low_px_s2: float = 16000.0
@export var grip_lateral_high_px_s2: float = 9000.0
@export var grip_speed_ref_px_s: float = 1600.0
@export var grip_lateral_min_px_s: float = 12.0
@export var align_vel_to_forward: float = 7.5

@export_group("Drift auto")
@export var drift_auto_actif: bool = true
@export var drift_vitesse_min_px_s: float = 320.0
@export var drift_steer_min: float = 0.35
@export var drift_grip_lat_mult: float = 0.30
@export var drift_align_mult: float = 0.38
@export var drift_steer_mult: float = 1.10
@export var drift_lat_kick_px_s2: float = 2400.0
@export var drift_kick_speed_ref_px_s: float = 1400.0
@export var drift_on_time_s: float = 0.10
@export var drift_off_time_s: float = 0.14

var _steer: float = 0.0
var _drift_t: float = 0.0

func traiter(vehicule: CharacterBody2D, dt: float, actif: bool = true) -> void:
	if vehicule == null or dt <= 0.0:
		return

	var throttle: float = 0.0
	var steer_in: float = 0.0

	if actif:
		throttle = Input.get_action_strength("haut") - Input.get_action_strength("bas")
		steer_in = Input.get_action_strength("droite") - Input.get_action_strength("gauche")

	var steer_rate: float = steer_smooth_in if absf(steer_in) > 0.001 else steer_smooth_out
	_steer = move_toward(_steer, steer_in, steer_rate * dt)

	var local_vel: Vector2 = vehicule.velocity.rotated(-vehicule.rotation)
	var fwd: float = -local_vel.y
	var lat: float = local_vel.x
	var abs_fwd: float = absf(fwd)

	var vmax_f: float = maxf(vitesse_max_avant_px_s, 1.0)
	var vmax_r: float = maxf(vitesse_max_arriere_px_s, 1.0)

	if not actif:
		fwd = move_toward(fwd, 0.0, (frein_moteur_px_s2 + friction_roulement_px_s2) * dt)
	else:
		if throttle > 0.01:
			fwd = move_toward(fwd, vmax_f, accel_avant_px_s2 * throttle * dt)
		elif throttle < -0.01:
			if fwd > 0.0:
				fwd = move_toward(fwd, 0.0, frein_px_s2 * (-throttle) * dt)
			else:
				fwd = move_toward(fwd, -vmax_r, accel_arriere_px_s2 * (-throttle) * dt)
		else:
			var decel: float = frein_moteur_px_s2 + friction_roulement_px_s2
			fwd = move_toward(fwd, 0.0, decel * dt)

	abs_fwd = absf(fwd)

	var want_drift: bool = drift_auto_actif and actif and abs_fwd >= drift_vitesse_min_px_s and absf(_steer) >= drift_steer_min

	if want_drift:
		_drift_t = minf(drift_on_time_s, _drift_t + dt)
	else:
		_drift_t = maxf(-drift_off_time_s, _drift_t - dt)

	var drift_alpha: float
	if _drift_t >= 0.0:
		drift_alpha = clampf(_drift_t / maxf(drift_on_time_s, 0.0001), 0.0, 1.0)
	else:
		drift_alpha = 0.0

	var t_steer: float = clampf(abs_fwd / maxf(steer_speed_ref_px_s, 1.0), 0.0, 1.0)
	var steer_mult: float = lerpf(steer_low_speed_mult, steer_high_speed_mult, t_steer)
	steer_mult *= lerpf(1.0, drift_steer_mult, drift_alpha)

	var sens: float = 1.0
	if abs_fwd > 4.0:
		sens = signf(fwd)

	if actif and absf(_steer) > 0.001 and abs_fwd > 1.0:
		vehicule.rotation += _steer * vitesse_rotation_rad_s * steer_mult * dt * sens

	if drift_alpha > 0.001:
		var tk: float = clampf(abs_fwd / maxf(drift_kick_speed_ref_px_s, 1.0), 0.0, 1.0)
		lat += _steer * drift_lat_kick_px_s2 * tk * dt * drift_alpha

	var t_grip: float = clampf(abs_fwd / maxf(grip_speed_ref_px_s, 1.0), 0.0, 1.0)
	var grip_lat: float = lerpf(grip_lateral_low_px_s2, grip_lateral_high_px_s2, t_grip)
	grip_lat *= lerpf(1.0, drift_grip_lat_mult, drift_alpha)

	if absf(lat) > grip_lateral_min_px_s:
		lat = move_toward(lat, 0.0, grip_lat * dt)
	else:
		lat = 0.0

	var new_local: Vector2 = Vector2(lat, -fwd)
	var new_vel: Vector2 = new_local.rotated(vehicule.rotation)

	var align_strength: float = align_vel_to_forward * lerpf(1.0, drift_align_mult, drift_alpha)

	var forward_vec: Vector2 = Vector2.UP.rotated(vehicule.rotation)
	var desired_dir: Vector2 = forward_vec if fwd >= 0.0 else -forward_vec
	var vlen: float = new_vel.length()

	if vlen > 0.001 and abs_fwd > 1.0:
		var cur_dir: Vector2 = new_vel / vlen
		var a_align: float = 1.0 - exp(-align_strength * dt)
		cur_dir = cur_dir.lerp(desired_dir, a_align).normalized()
		new_vel = cur_dir * vlen

	vehicule.velocity = new_vel
	vehicule.move_and_slide()
