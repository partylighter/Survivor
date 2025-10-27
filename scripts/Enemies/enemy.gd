extends CharacterBody2D
class_name Enemy

signal mort
signal reapparu

enum TypeEnnemi {C, B, A, S, BOSS}

@export_group("Type")
@export_enum("C","B","A","S","BOSS") var type_ennemi: int = TypeEnnemi.C

@export var valeur_score: int = 10
@export var speed: float = 120.0
@export_node_path("Node") var chemin_sante: NodePath

@export var recul_amorti: float = 18.0
@export var recul_max: float = 500.0

@export_group("Secousse")
@export var secousse_force_px: float = 4.0      # taille du shake visuel en pixels
@export var secousse_duree_s: float = 0.12      # durée totale du shake

var recul: Vector2 = Vector2.ZERO
var deja_mort: bool = false
var _doit_emit_reapparu_next_frame: bool = false

var _layer_orig: int = -1
var _mask_orig: int = -1

var _ai_enabled: bool = true

var _secousse_t: float = 0.0
var _sprite_pos_neutre: Vector2 = Vector2.ZERO

@onready var sante: Sante = get_node(chemin_sante) as Sante
@onready var target: Player = _find_player(get_tree().current_scene)
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite_pos_neutre = sprite.position

	if sante:
		sante.died.connect(_on_mort)

	if self is CollisionObject2D:
		_layer_orig = collision_layer
		_mask_orig = collision_mask

func get_type_id() -> int:
	return type_ennemi

func get_type_nom() -> StringName:
	return StringName(TypeEnnemi.find_key(type_ennemi))

func get_score() -> int:
	return valeur_score

func appliquer_recul(direction: Vector2, force: float) -> void:
	recul += direction.normalized() * max(force, 0.0)
	var m := recul.length()
	if m > recul_max:
		recul = recul * (recul_max / m)

	_prendre_coup_visuel()

func _prendre_coup_visuel() -> void:
	_secousse_t = secousse_duree_s

func appliquer_recul_depuis(source: Node2D, force: float) -> void:
	var dir := global_position - source.global_position
	appliquer_recul(dir, force)

func _physics_process(dt: float) -> void:
	if _doit_emit_reapparu_next_frame:
		_doit_emit_reapparu_next_frame = false
		emit_signal("reapparu")

	if deja_mort:
		return

	if not _ai_enabled:
		return

	if target != null and recul.length_squared() < 1.0:
		var d := target.global_position - global_position
		var L := d.length()
		velocity = (d / (L if L > 0.0001 else 1.0)) * speed

	velocity += recul

	var alpha: float = clamp(recul_amorti * dt, 0.0, 0.95)
	recul = recul.lerp(Vector2.ZERO, alpha)
	if recul.length_squared() < 1.0:
		recul = Vector2.ZERO

	# effet visuel de secousse du sprite (pas de shader)
	if _secousse_t > 0.0:
		_secousse_t -= dt
		var ratio := _secousse_t / secousse_duree_s
		if ratio < 0.0:
			ratio = 0.0

		var offset := Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * secousse_force_px * ratio

		sprite.position = _sprite_pos_neutre + offset
	else:
		sprite.position = _sprite_pos_neutre

	move_and_slide()

func _find_player(n: Node) -> Player:
	if n is Player:
		return n
	for c in n.get_children():
		var p := _find_player(c)
		if p:
			return p
	return null

func _on_mort() -> void:
	if deja_mort:
		return
	deja_mort = true

	if self is CollisionObject2D:
		if _layer_orig < 0:
			_layer_orig = collision_layer
		if _mask_orig < 0:
			_mask_orig = collision_mask

		if not has_meta("sl"):
			set_meta("sl", _layer_orig)
		if not has_meta("sm"):
			set_meta("sm", _mask_orig)

		collision_layer = 0
		collision_mask = 0

	visible = false
	velocity = Vector2.ZERO
	recul = Vector2.ZERO

	set_physics_process(false)
	set_process(false)

	_ai_enabled = false

	emit_signal("mort")

func reactiver_apres_pool() -> void:
	deja_mort = false

	if sante:
		var max_pv_now: float = float(sante.get("max_pv"))
		sante.set("pv", max_pv_now)

	visible = true
	velocity = Vector2.ZERO
	recul = Vector2.ZERO

	set_physics_process(true)
	set_process(true)

	_ai_enabled = true

	_doit_emit_reapparu_next_frame = true

	# reset secousse
	_secousse_t = 0.0
	sprite.position = _sprite_pos_neutre

func set_combat_state(actif_moteur: bool, _collision_joueur: bool) -> void:
	if deja_mort:
		return

	_ai_enabled = actif_moteur

	set_physics_process(actif_moteur)
	set_process(actif_moteur)

	if self is CollisionObject2D:
		if has_meta("sl"):
			collision_layer = get_meta("sl")
		elif _layer_orig >= 0:
			collision_layer = _layer_orig

		if has_meta("sm"):
			collision_mask = get_meta("sm")
		elif _mask_orig >= 0:
			collision_mask = _mask_orig
