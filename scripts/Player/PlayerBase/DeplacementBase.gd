extends Node
class_name DeplacementBase

@export_group("Conduite")
@export var vitesse_max_px_s: float = 520.0
@export var accel_px_s2: float = 2200.0
@export var frein_px_s2: float = 3200.0
@export var friction_px_s2: float = 1600.0
@export var vitesse_rotation_rad_s: float = 3.2
@export var rotation_scaling: float = 0.9
@export var grip: float = 18.0

var _speed: float = 0.0

func traiter(vehicule: CharacterBody2D, dt: float, actif: bool = true) -> void:
	if vehicule == null or dt <= 0.0:
		return

	var vmax: float = maxf(vitesse_max_px_s, 1.0)

	var throttle: float = 0.0
	var steer: float = 0.0

	if actif:
		throttle = Input.get_action_strength("haut") - Input.get_action_strength("bas")
		steer = Input.get_action_strength("droite") - Input.get_action_strength("gauche")

	if absf(throttle) > 0.01:
		var cible: float = throttle * vmax
		var a: float = accel_px_s2 if signf(cible) == signf(_speed) else frein_px_s2
		_speed = move_toward(_speed, cible, a * dt)
	else:
		_speed = move_toward(_speed, 0.0, friction_px_s2 * dt)

	if actif and absf(steer) > 0.01:
		var ratio: float = clampf(absf(_speed) / vmax, 0.0, 1.0)
		var steer_mult: float = (0.35 + 0.65 * ratio) * rotation_scaling
		var sens: float = signf(_speed) if absf(_speed) > 1.0 else 1.0
		vehicule.rotation += steer * vitesse_rotation_rad_s * steer_mult * dt * sens

	var forward: Vector2 = Vector2.UP.rotated(vehicule.rotation)
	var v_des: Vector2 = forward * _speed

	var cible_vel: Vector2 = v_des if actif else Vector2.ZERO
	vehicule.velocity = vehicule.velocity.move_toward(cible_vel, grip * dt * vmax)

	vehicule.move_and_slide()
