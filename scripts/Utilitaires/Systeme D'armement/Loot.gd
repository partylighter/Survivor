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
@export var pickup_radius: float = 18.0
@export var lifetime_s: float = 3.0

var _t: float = 0.0
var magnet_active: bool = false
var target_player: Node2D = null
var _active: bool = true

func _ready() -> void:
	add_to_group("loots")
	set_physics_process(true)
	var root := get_tree().current_scene
	if root and root.has_node("Player"):
		target_player = root.get_node("Player") as Node2D

func set_active(v: bool) -> void:
	_active = v
	set_physics_process(v)

func _physics_process(delta: float) -> void:
	if lifetime_s > 0.0:
		_t += delta
		if _t >= lifetime_s:
			queue_free()
			return

	if target_player == null or not is_instance_valid(target_player):
		return

	var d2 := global_position.distance_squared_to(target_player.global_position)
	var r_magnet2 := magnet_radius * magnet_radius
	var r_pickup2 := pickup_radius * pickup_radius

	if not magnet_active and d2 <= r_magnet2:
		magnet_active = true

	if magnet_active:
		var dir := (target_player.global_position - global_position).normalized()
		global_position += dir * magnet_speed * delta

	if d2 <= r_pickup2:
		_on_collected(target_player)

func prendre_payload() -> Dictionary:
	var d := {
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

func _on_collected(player: Node2D) -> void:
	var payload := prendre_payload()
	if player != null and player.has_method("on_loot_collected"):
		player.on_loot_collected(payload)
	queue_free()
