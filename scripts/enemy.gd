extends CharacterBody2D
class_name Enemy

signal mort

enum TypeEnnemi {C, B, A, S, BOSS}

@export_group("Type")
@export_enum("C","B","A","S","BOSS") var type_ennemi: int = TypeEnnemi.C

@export var valeur_score: int = 10

@export var speed: float = 120.0
@export_node_path("Node") var chemin_sante: NodePath

@export var recul_amorti: float = 18.0
@export var recul_max: float = 500.0
var recul: Vector2 = Vector2.ZERO

@onready var sante: Sante = get_node(chemin_sante) as Sante
@onready var target: Player = _find_player(get_tree().current_scene)

func _ready() -> void:
	if sante:
		sante.died.connect(_on_mort)

func get_type_id() -> int:
	return type_ennemi

func get_type_nom() -> StringName:
	return StringName(TypeEnnemi.find_key(type_ennemi))

func get_score() -> int:
	return valeur_score

func appliquer_recul(direction: Vector2, force: float) -> void:
	# additionne les impacts et limite la magnitude
	recul += direction.normalized() * max(force, 0.0)
	var m := recul.length()
	if m > recul_max:
		recul = recul * (recul_max / m)

func appliquer_recul_depuis(source: Node2D, force: float) -> void:
	var dir := global_position - source.global_position
	appliquer_recul(dir, force)


func _physics_process(dt: float) -> void:
	if target != null and recul.length_squared() < 1.0:
		var d := target.global_position - global_position
		var L := d.length()
		velocity = (d / (L if L > 0.0001 else 1.0)) * speed
	velocity += recul

	# DECROISSANCE EXPONENTIELLE + SEUIL ZERO
	var alpha :float = clamp(recul_amorti * dt, 0.0, 0.95) # proportion absorbée cette frame
	recul = recul.lerp(Vector2.ZERO, alpha)
	if recul.length_squared() < 1.0:
		recul = Vector2.ZERO

	move_and_slide()

func _find_player(n: Node) -> Player:
	if n is Player: return n
	for c in n.get_children():
		var p := _find_player(c)
		if p: return p
	return null

func _on_mort() -> void:
	emit_signal("mort")
	queue_free()
