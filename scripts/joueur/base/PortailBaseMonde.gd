extends Area2D
class_name PortailBaseMonde

@export var chemin_spawn_monde: NodePath
@export var chemin_spawn_base: NodePath
@export_range(0.0, 2.0, 0.01) var verrou_s: float = 0.20

var spawn_monde: Node2D
var spawn_base: Node2D
var _verrou_local: bool = false

func _ready() -> void:
	spawn_monde = get_node_or_null(chemin_spawn_monde) as Node2D
	spawn_base = get_node_or_null(chemin_spawn_base) as Node2D

func _on_body_entered(body: Node) -> void:
	if _verrou_local:
		return
	if EtatJeu.transition_en_cours:
		return
	if not (body is Player):
		return

	_verrou_local = true
	EtatJeu.transition_en_cours = true

	set_deferred("monitoring", false)

	var joueur := body as Player

	if EtatJeu.zone_actuelle == EtatJeu.Zone.MONDE:
		EtatJeu.entrer_base(joueur, spawn_base, spawn_monde)
	else:
		EtatJeu.sortir_base(joueur, spawn_monde)

	_deverrouiller()

func _deverrouiller() -> void:
	if verrou_s <= 0.0:
		_verrou_local = false
		EtatJeu.transition_en_cours = false
		set_deferred("monitoring", true)
		return

	await get_tree().create_timer(verrou_s).timeout
	_verrou_local = false
	EtatJeu.transition_en_cours = false
	set_deferred("monitoring", true)
