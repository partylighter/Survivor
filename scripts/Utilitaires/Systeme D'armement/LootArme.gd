extends Area2D
class_name LootArme

@export var arme_scene: PackedScene
@export var debug_enabled: bool = true
@export var frein: float = 12.0
@export_range(0.0,1.0,0.01) var restitution: float = 0.55
@export var seuil_bounce: float = 80.0
@export var seuil_stop: float = 16.0
@export var max_bounces: int = 1
@export var jitter_bounce_deg: float = 10.0

@onready var sprite: Sprite2D = $Sprite2D

var linear_velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var moving: bool = false
var bounces: int = 0
var _cooldown: float = 0.0

# --- Nouveaux états de debug ---
var _was_above_thresh: bool = false
var _log_acc: float = 0.0

func _d(m:String)->void:
	if debug_enabled: print("[LootArme]", Time.get_ticks_msec(), m)

func _ready() -> void:
	_d("READY " + name + " pos=" + str(global_position))
	_d("PARAMS frein=%s rest=%s seuil_bounce=%s seuil_stop=%s max_b=%s jitter=%s" %
		[frein, restitution, seuil_bounce, seuil_stop, max_bounces, jitter_bounce_deg])

func definir_texture(tex: Texture2D) -> void:
	if sprite:
		sprite.texture = tex
		_d("SET_TEXTURE " + str(tex))

func _physics_process(dt: float) -> void:
	var speed_prev: float = linear_velocity.length()

	# Frottement expo + intégration
	linear_velocity *= exp(-frein * dt)
	position += linear_velocity * dt

	rotation += angular_velocity * dt
	angular_velocity *= exp(-8.0 * dt)

	var speed: float = linear_velocity.length()

	# Démarrage mouvement
	if not moving and speed > 0.1:
		moving = true
		_d("MOVE_START v=" + str(linear_velocity) + " | speed=" + str(speed))

	# Cooldown
	if _cooldown > 0.0:
		_cooldown -= dt
		if _cooldown <= 0.0:
			_d("COOLDOWN_DONE")

	# Détection FRANCHISSEMENT du seuil (au lieu de lire juste 'speed <= seuil')
	var crossed := _was_above_thresh and (speed <= seuil_bounce)
	_was_above_thresh = (speed > seuil_bounce)

	if moving and crossed:
		# On a franchi le seuil ; décider si rebond ou non et LOGUER LA RAISON
		if bounces >= max_bounces:
			_d("NO_BOUNCE: MAX_REACHED bounces=%s max=%s" % [bounces, max_bounces])
		elif _cooldown > 0.0:
			_d("NO_BOUNCE: COOLDOWN_ACTIVE cd=%.3f" % _cooldown)
		elif speed < 0.01:
			_d("NO_BOUNCE: SPEED_ZERO")
		else:
			var dir := -linear_velocity.normalized()
			var jitter := deg_to_rad(randf_range(-jitter_bounce_deg, jitter_bounce_deg))
			dir = dir.rotated(jitter)
			var speed_new := speed * restitution
			_d("BOUNCE_TRY: prev_speed=%.2f -> thresh=%s -> new_speed=%.2f rest=%.2f jitter=%.2fdeg" %
				[speed_prev, seuil_bounce, speed_new, restitution, rad_to_deg(jitter)])
			linear_velocity = dir * speed_new
			angular_velocity *= restitution
			bounces += 1
			_cooldown = 0.12
			_d("BOUNCE_OK: count=%s v=%s" % [bounces, str(linear_velocity)])

	# Arrêt
	if moving and speed <= seuil_stop and absf(angular_velocity) <= 0.05:
		_d("STOP_COND: speed=%.2f<=%.2f spin=%.2f<=0.05" % [speed, seuil_stop, absf(angular_velocity)])
		moving = false
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		bounces = 0
		_cooldown = 0.0
		_was_above_thresh = false
		_d("MOVE_STOP pos=" + str(global_position))

	# LOG d'état périodique (toutes les ~0.25s)
	if debug_enabled:
		_log_acc += dt
		if _log_acc >= 0.25:
			_log_acc = 0.0
			_d("STATE pos=%s v=%s speed=%.2f bounces=%s cd=%.2f above=%s" %
				[str(global_position), str(linear_velocity), speed, bounces, maxf(_cooldown, 0.0), _was_above_thresh])
