extends Area2D
class_name HitBox

@export var damage: int = 10
@export_node_path("Node") var chemin_hote: NodePath
@export var active_par_defaut: bool = false
@export var force_recul: float = 300.0

@onready var shape: CollisionShape2D = $CollisionShape2D
var single_hit: bool = true
var hote_ref: Node
var already_hit := {}
var _en_cours: bool = false

func _ready() -> void:
	hote_ref = get_node_or_null(chemin_hote)
	area_entered.connect(_on_area_entered)
	set_deferred("monitoring", active_par_defaut)
	if shape: shape.set_deferred("disabled", not active_par_defaut)

func activer_pendant(duree: float) -> void:
	if _en_cours: return
	_en_cours = true
	already_hit.clear()
	set_deferred("monitoring", true)
	if shape: shape.set_deferred("disabled", false)
	await get_tree().create_timer(duree).timeout
	set_deferred("monitoring", false)
	if shape: shape.set_deferred("disabled", true)
	_en_cours = false

func _on_area_entered(a: Area2D) -> void:
	if a is HurtBox:
		if single_hit and a in already_hit:
			return
		(a as HurtBox).tek_it(damage, hote_ref if hote_ref else self)
		var cible := a.get_parent()
		if cible and cible.has_method("appliquer_recul_depuis"):
			var source_nd2 := (hote_ref as Node2D) if hote_ref is Node2D else self
			cible.appliquer_recul_depuis(source_nd2, force_recul)
		if single_hit:
			already_hit[a] = true
