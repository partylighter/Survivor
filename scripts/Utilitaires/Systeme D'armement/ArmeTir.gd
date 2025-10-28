extends ArmeBase
class_name ArmeTir

@export var projectile_scene: PackedScene 
@export var vitesse_projectile: float = 1400.0

func attaquer() -> void:
	if not peut_attaquer():
		return
	if projectile_scene == null:
		return

	_pret = false

	var p := projectile_scene.instantiate() as Projectile
	if p == null:
		_pret = true
		return

	# position de départ du tir = position actuelle de l'arme
	var start_pos: Vector2 = global_position

	# direction du tir = vers la souris (vue du haut style survivor)
	var cible: Vector2 = get_global_mouse_position()
	var dir: Vector2 = (cible - start_pos).normalized()

	# configure la balle
	p.configurer(
		degats,
		dir,
		vitesse_projectile,
		recul_force,
		porteur
	)

	# ajoute la balle dans la scène du jeu
	get_tree().current_scene.add_child(p)
	p.global_position = start_pos

	# cooldown du tir
	await get_tree().create_timer(cooldown_s).timeout
	_pret = true
