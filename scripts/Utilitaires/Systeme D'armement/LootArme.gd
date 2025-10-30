extends Area2D
class_name LootArme

@export var arme_scene: PackedScene
@export var debug_enabled: bool = true

@export var frein_sol: float = 14.0
@export var trainee_air: float = 2.5
@export var gravite_z: float = 2200.0
@export_range(0.0,1.0,0.01) var restitution_z: float = 0.38
@export_range(0.0,1.0,0.01) var frein_bounce: float = 0.85
@export var seuil_stop_sol: float = 18.0
@export var seuil_rebond_z: float = 80.0
@export var seuil_stop_spin: float = 0.05

@onready var sprite: Sprite2D = $Sprite2D

var linear_velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var z: float = 0.0
var vz: float = 0.0
var en_mouvement: bool = false

func _d(m:String)->void:
	if debug_enabled: print("[LootArme]", Time.get_ticks_msec(), m)

func _ready() -> void:
	_d("READY " + name + " pos=" + str(global_position))

func definir_texture(tex: Texture2D) -> void:
	if sprite:
		sprite.texture = tex

func _physics_process(dt: float) -> void:
	var v_prev := linear_velocity

	# axe z simulé
	vz -= gravite_z * dt
	z += vz * dt
	if z <= 0.0:
		z = 0.0
		if vz < 0.0:
			vz = -vz * restitution_z
			linear_velocity *= frein_bounce
		if absf(vz) < seuil_rebond_z:
			vz = 0.0

	# frottements
	if z == 0.0:
		linear_velocity = linear_velocity.move_toward(Vector2.ZERO, frein_sol * dt)
	else:
		linear_velocity = linear_velocity.move_toward(Vector2.ZERO, trainee_air * dt)

	# intégration plan + spin
	position += linear_velocity * dt
	rotation += angular_velocity * dt
	angular_velocity = move_toward(angular_velocity, 0.0, 8.0 * dt)

	# états
	var speed := linear_velocity.length()
	if not en_mouvement and (speed > 0.1 or absf(vz) > 0.1):
		en_mouvement = true
		_d("MOVE_START v=" + str(v_prev) + " vz=" + str(vz))
	if en_mouvement and z == 0.0 and speed <= seuil_stop_sol and vz == 0.0 and absf(angular_velocity) <= seuil_stop_spin:
		en_mouvement = false
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		_d("MOVE_STOP pos=" + str(global_position))
