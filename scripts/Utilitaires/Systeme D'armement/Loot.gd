extends Area2D
class_name Loot

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

var _life_t: float = 0.0
var _magnet_t: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _seed: float = 0.0

var magnet_active: bool = false
var target_player: Node2D = null
var _active: bool = true
var _collecting: bool = false

@onready var anim: LootAnim = get_node_or_null(anim_path) as LootAnim

func _ready() -> void:
	add_to_group("loots")
	set_physics_process(true)
	_seed = randf() * TAU

	var root := get_tree().current_scene
	if root and root.has_node("Player"):
		target_player = root.get_node("Player") as Node2D

func set_active(v: bool) -> void:
	_active = v
	set_physics_process(v)

func _physics_process(delta: float) -> void:
	if not _active or _collecting:
		return

	if lifetime_s > 0.0:
		_life_t += delta
		if _life_t >= lifetime_s:
			queue_free()
			return

	if target_player == null or not is_instance_valid(target_player):
		return

	var pos_pickup: Vector2 = _get_pickup_pos()
	var vers_joueur: Vector2 = pos_pickup - global_position
	var d2: float = vers_joueur.length_squared()

	var r_magnet2: float = magnet_radius * magnet_radius
	var r_pickup2: float = pickup_radius * pickup_radius

	if not magnet_active:
		if anim != null:
			anim.maj_idle(delta)
		if d2 <= r_magnet2:
			magnet_active = true
			if anim != null:
				anim.on_debut_aimant()
	else:
		_magnet_t += delta

		var dist: float = sqrt(maxf(d2, 0.000001))
		var dir: Vector2 = vers_joueur / dist
		var dist01: float = float(clamp(dist / maxf(magnet_radius, 0.0001), 0.0, 1.0))

		var speed: float = magnet_speed * (1.0 + (1.0 - dist01) * (magnet_speed_close_mult - 1.0))

		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var bell: float = dist01 * (1.0 - dist01) * 4.0

		var swirl: Vector2 = perp * sin((_magnet_t * magnet_swirl_freq) + _seed) * speed * magnet_swirl_strength * bell

		var desired_vel: Vector2 = (dir * speed) + swirl
		_vel = _vel.move_toward(desired_vel, magnet_accel * delta)

		global_position += _vel * delta

		if anim != null:
			anim.maj_aimant(_vel, delta)

		pos_pickup = _get_pickup_pos()
		d2 = global_position.distance_squared_to(pos_pickup)

	if d2 <= r_pickup2:
		_start_collect()

func _get_pickup_pos() -> Vector2:
	if target_player != null and is_instance_valid(target_player) and target_player.has_node("LootTarget"):
		var n: Node = target_player.get_node("LootTarget")
		if n is Node2D:
			return (n as Node2D).global_position
	return target_player.global_position

func _start_collect() -> void:
	if _collecting:
		return
	_collecting = true

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)

	var joueur: Node2D = target_player
	var payload: Dictionary = prendre_payload()
	var pos_fin: Vector2 = _get_pickup_pos()

	if anim != null:
		anim.jouer_collecte(self, pos_fin, collect_time_s, Callable(self, "_finish_collect").bind(joueur, payload))
	else:
		_finish_collect(joueur, payload)

func _finish_collect(joueur: Node2D, payload: Dictionary) -> void:
	if joueur != null and is_instance_valid(joueur) and joueur.has_method("on_loot_collected"):
		joueur.on_loot_collected(payload)
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
