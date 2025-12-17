extends Area2D
class_name Loot

const ACT_RIEN: int = 0
const ACT_VERS_AIMANT: int = 1
const ACT_SUPPRIMER: int = 2

enum TypeLoot { C, B, A, S }
enum TypeItem { CONSO, UPGRADE, ARME }

@export_enum("C","B","A","S") var type_loot: int = TypeLoot.C
@export_enum("CONSO","UPGRADE","ARME") var type_item: int = TypeItem.CONSO

@export var item_id: StringName = &""
@export var quantite: int = 1
@export var scene_contenu: PackedScene

@export var magnet_radius: float = 220.0
@export var magnet_speed: float = 420.0
@export var magnet_speed_close_mult: float = 2.2
@export var magnet_accel: float = 3800.0
@export var magnet_swirl_strength: float = 0.35
@export var magnet_swirl_freq: float = 10.0

@export var pickup_radius: float = 18.0
@export var collect_time_s: float = 0.10
@export var lifetime_s: float = 3.0

@export var anim_path: NodePath

var joueur_cible: Node2D = null

var _collecte: bool = false
var _t_aimant: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _seed: float = 0.0
var _die_ms: int = -1

var _r2_aimant: float = 0.0
var _r2_pickup: float = 0.0

var _lm: LootManager = null
@warning_ignore("unused_private_class_variable")
var _lm_liste: int = -1
@warning_ignore("unused_private_class_variable")
var _lm_index: int = -1

@onready var anim: LootAnim = get_node_or_null(anim_path) as LootAnim

func _enter_tree() -> void:
	add_to_group("loots")

func _ready() -> void:
	set_physics_process(false)

	_seed = randf() * TAU
	_r2_aimant = magnet_radius * magnet_radius
	_r2_pickup = pickup_radius * pickup_radius

	if lifetime_s > 0.0:
		_die_ms = Time.get_ticks_msec() + int(lifetime_s * 1000.0)

	set_deferred("monitoring", false)
	set_deferred("monitorable", true)

	call_deferred("_essayer_s_inscrire_manager")

func _essayer_s_inscrire_manager() -> void:
	if _lm != null:
		return

	var n: Node = get_tree().get_first_node_in_group("loot_manager")
	if n is LootManager:
		(n as LootManager).enregistrer_loot(self)
		return

	var root := get_tree().current_scene
	if root != null:
		var p := root.get_node_or_null("Player")
		if p is Node2D:
			joueur_cible = p as Node2D

func _exit_tree() -> void:
	if _lm != null and is_instance_valid(_lm):
		_lm.retirer_loot(self)

func tick_attente(dt: float, pos_pickup: Vector2) -> int:
	if _collecte:
		return ACT_SUPPRIMER

	if anim != null and not anim.idle_gpu:
		anim.maj_idle(dt)

	if _die_ms != -1 and Time.get_ticks_msec() >= _die_ms:
		queue_free()
		return ACT_SUPPRIMER

	var vers: Vector2 = pos_pickup - global_position
	var d2: float = vers.length_squared()

	if d2 <= _r2_pickup:
		_demarrer_collecte(pos_pickup)
		return ACT_SUPPRIMER

	if d2 <= _r2_aimant:
		_t_aimant = 0.0
		if anim != null:
			anim.on_debut_aimant()
		return ACT_VERS_AIMANT

	return ACT_RIEN

func tick_aimant(dt: float, pos_pickup: Vector2) -> int:
	if _collecte:
		return ACT_SUPPRIMER

	if _die_ms != -1 and Time.get_ticks_msec() >= _die_ms:
		queue_free()
		return ACT_SUPPRIMER

	var vers: Vector2 = pos_pickup - global_position
	var d2: float = vers.length_squared()

	var dist: float = sqrt(maxf(d2, 0.000001))
	var dir: Vector2 = vers / dist
	var dist01: float = clamp(dist / maxf(magnet_radius, 0.0001), 0.0, 1.0)

	var speed: float = magnet_speed * (1.0 + (1.0 - dist01) * (magnet_speed_close_mult - 1.0))

	_t_aimant += dt

	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var bell: float = dist01 * (1.0 - dist01) * 4.0
	var swirl: Vector2 = perp * sin((_t_aimant * magnet_swirl_freq) + _seed) * (speed * magnet_swirl_strength * bell)

	var desired: Vector2 = (dir * speed) + swirl
	_vel = _vel.move_toward(desired, magnet_accel * dt)

	global_position += _vel * dt

	if anim != null:
		anim.maj_aimant(_vel, dt)

	if global_position.distance_squared_to(pos_pickup) <= _r2_pickup:
		_demarrer_collecte(pos_pickup)
		return ACT_SUPPRIMER

	return ACT_RIEN

func tick_lointain() -> bool:
	if _collecte:
		return true
	if _die_ms != -1 and Time.get_ticks_msec() >= _die_ms:
		queue_free()
		return true
	return false

func _demarrer_collecte(pos_fin: Vector2) -> void:
	if _collecte:
		return
	_collecte = true

	var j: Node2D = joueur_cible
	var payload: Dictionary = prendre_payload()

	if anim != null:
		anim.jouer_collecte(self, pos_fin, collect_time_s, Callable(self, "_finir_collecte").bind(j, payload))
	else:
		_finir_collecte(j, payload)

func _finir_collecte(j: Node2D, payload: Dictionary) -> void:
	if j != null and is_instance_valid(j) and j.has_method("on_loot_collected"):
		j.on_loot_collected(payload)
	queue_free()

func prendre_payload() -> Dictionary:
	var d: Dictionary = {
		"type_loot": type_loot,
		"type_item": type_item,
		"id": item_id,
		"quantite": quantite,
		"scene": scene_contenu
	}
	vider()
	return d

func vider() -> void:
	quantite = 0
	type_loot = TypeLoot.C
	item_id = &""
	scene_contenu = null
