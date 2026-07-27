class_name JoueurHD2D
extends CharacterBody3D

const DIRECTIONS_IMAGES: Dictionary = {
	Vector2.DOWN: 0,
	Vector2(-1, 1): 2,
	Vector2.LEFT: 4,
	Vector2(-1, -1): 6,
	Vector2.UP: 8,
	Vector2(1, -1): 10,
	Vector2.RIGHT: 12,
	Vector2(1, 1): 14
}

@export_group("Déplacement")
@export var vitesse_px_s: float = 1180.0
@export var acceleration_px_s2: float = 23500.0
@export var deceleration_px_s2: float = 8500.0
@export var echelle_unite_par_px: float = PlanHD2D.ECHELLE_UNITE_PAR_PX

@export_group("Dash")
@export var multiplicateur_vitesse_dash: float = 3.0
@export var duree_dash_s: float = 0.15
@export var recharge_dash_s: float = 0.35

@export_group("Visuel")
@export_node_path("Sprite3D") var chemin_visuel: NodePath = NodePath("Visuel")
@export_node_path("Camera3D") var chemin_camera: NodePath = NodePath("CameraRig/Camera3D")
@export var images_par_seconde: float = 6.0

@onready var visuel: Sprite3D = get_node_or_null(chemin_visuel) as Sprite3D
@onready var camera_joueur: Camera3D = get_node_or_null(chemin_camera) as Camera3D

var _direction_dash: Vector2 = Vector2.ZERO
var _direction_visee: Vector2 = Vector2.DOWN
var _temps_dash_restant_s: float = 0.0
var _temps_recharge_dash_s: float = 0.0
var _temps_animation_s: float = 0.0

func _ready() -> void:
	add_to_group(&"joueur_hd2d")
	_mettre_a_jour_visuel(Vector2.ZERO)

func _physics_process(delta: float) -> void:
	var entree: Vector2 = Input.get_vector(&"gauche", &"droite", &"haut", &"bas")
	_mettre_a_jour_visee()
	_mettre_a_jour_dash(entree, delta)
	var direction_active: Vector2 = _direction_dash if _temps_dash_restant_s > 0.0 else entree
	var multiplicateur: float = multiplicateur_vitesse_dash if _temps_dash_restant_s > 0.0 else 1.0
	var vitesse_cible: Vector2 = direction_active.normalized() * vitesse_px_s * echelle_unite_par_px * multiplicateur if direction_active.length_squared() > 0.0001 else Vector2.ZERO
	var vitesse_plan: Vector2 = Vector2(velocity.x, velocity.z)
	var variation: float = acceleration_px_s2 if vitesse_cible != Vector2.ZERO else deceleration_px_s2
	vitesse_plan = vitesse_plan.move_toward(vitesse_cible, variation * echelle_unite_par_px * delta)
	velocity = Vector3(vitesse_plan.x, 0.0, vitesse_plan.y)
	move_and_slide()
	_mettre_a_jour_visuel(entree)

func _mettre_a_jour_dash(entree: Vector2, delta: float) -> void:
	_temps_recharge_dash_s = maxf(_temps_recharge_dash_s - delta, 0.0)
	_temps_dash_restant_s = maxf(_temps_dash_restant_s - delta, 0.0)
	if _temps_dash_restant_s <= 0.0:
		_direction_dash = Vector2.ZERO
	if not Input.is_action_just_pressed(&"dash") or _temps_recharge_dash_s > 0.0 or entree.length_squared() <= 0.0001:
		return
	_direction_dash = entree.normalized()
	_temps_dash_restant_s = duree_dash_s
	_temps_recharge_dash_s = recharge_dash_s

func _mettre_a_jour_visee() -> void:
	if camera_joueur == null:
		return
	var origine: Vector3 = camera_joueur.project_ray_origin(get_viewport().get_mouse_position())
	var direction: Vector3 = camera_joueur.project_ray_normal(get_viewport().get_mouse_position())
	var intersection: Variant = Plane(Vector3.UP, global_position.y).intersects_ray(origine, direction)
	if intersection == null:
		return
	var point_sol: Vector3 = intersection as Vector3
	var direction_plan: Vector2 = Vector2(point_sol.x - global_position.x, point_sol.z - global_position.z)
	if direction_plan.length_squared() > 0.0001:
		_direction_visee = direction_plan.normalized()

func _mettre_a_jour_visuel(entree: Vector2) -> void:
	if visuel == null:
		return
	var image_base: int = _trouver_image_direction(_direction_visee)
	if entree.length_squared() > 0.0001:
		_temps_animation_s += get_physics_process_delta_time()
		var image_marche: int = int(floor(_temps_animation_s * images_par_seconde)) % 2
		visuel.frame = image_base + image_marche
	else:
		_temps_animation_s = 0.0
		visuel.frame = image_base

func _trouver_image_direction(direction: Vector2) -> int:
	var meilleure_image: int = 0
	var meilleur_score: float = -INF
	for direction_image: Vector2 in DIRECTIONS_IMAGES:
		var score: float = direction.normalized().dot(direction_image.normalized())
		if score > meilleur_score:
			meilleur_score = score
			meilleure_image = int(DIRECTIONS_IMAGES[direction_image])
	return meilleure_image
