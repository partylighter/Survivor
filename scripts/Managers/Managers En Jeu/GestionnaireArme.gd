extends Node2D
class_name GestionnaireArme

@export_node_path("Node2D") var chemin_socket_gauche: NodePath
@export_node_path("Node2D") var chemin_socket_droite: NodePath
@export var rayon_socket: float = 24.0

var arme_gauche: ArmeBase = null
var arme_droite: ArmeBase = null

var _socket_gauche: Node2D
var _socket_droite: Node2D
var _joueur: Player

func _ready() -> void:
	_socket_gauche = get_node(chemin_socket_gauche) as Node2D
	_socket_droite = get_node(chemin_socket_droite) as Node2D
	_joueur = get_parent() as Player

func _process(_dt: float) -> void:
	_mettre_a_jour_sockets()
	_gestion_attaques()

func _mettre_a_jour_sockets() -> void:
	var cible: Vector2 = get_global_mouse_position()
	var dir: Vector2 = (cible - global_position).normalized()
	var ortho: Vector2 = Vector2(-dir.y, dir.x)

	_socket_gauche.position = ortho * rayon_socket
	_socket_droite.position = -ortho * rayon_socket

	var angle_tir: float = dir.angle()
	_socket_gauche.rotation = angle_tir
	_socket_droite.rotation = angle_tir

	if arme_gauche:
		arme_gauche.rotation = angle_tir
	if arme_droite:
		arme_droite.rotation = angle_tir

func _gestion_attaques() -> void:
	if Input.is_action_just_pressed("attaque_main_gauche"):
		if arme_gauche and arme_gauche.peut_attaquer():
			arme_gauche.attaquer()

	if Input.is_action_just_pressed("attaque_main_droite"):
		if arme_droite and arme_droite.peut_attaquer():
			arme_droite.attaquer()

func equiper_arme_gauche(a: ArmeBase) -> void:
	if a == null:
		return
	arme_gauche = a
	a.equipe_par(_joueur)
	_socket_gauche.add_child(a)
	a.position = Vector2.ZERO
	a.rotation = _socket_gauche.rotation

func equiper_arme_droite(a: ArmeBase) -> void:
	if a == null:
		return
	arme_droite = a
	a.equipe_par(_joueur)
	_socket_droite.add_child(a)
	a.position = Vector2.ZERO
	a.rotation = _socket_droite.rotation
