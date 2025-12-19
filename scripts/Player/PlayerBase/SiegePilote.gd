extends Node
class_name SiegePilote

@export_group("Refs")
@export var chemin_seat_area: NodePath
@export var chemin_seat_marker: NodePath
@export var chemin_exit_marker: NodePath

@export_group("Input")
@export var action_interagir: StringName = &"interagir"

@export_group("Debug")
@export var debug_siege: bool = true

var conducteur: CharacterBody2D = null
var _candidat: CharacterBody2D = null

var _parent_conducteur: Node = null
var _driver_layer: int = 0
var _driver_mask: int = 0
var _driver_physics_on: bool = true

@onready var vehicule: CharacterBody2D = get_parent() as CharacterBody2D
@onready var seat_area: Area2D = get_node_or_null(chemin_seat_area) as Area2D
@onready var seat_marker: Node2D = get_node_or_null(chemin_seat_marker) as Node2D
@onready var exit_marker: Node2D = get_node_or_null(chemin_exit_marker) as Node2D

func _ready() -> void:
	if debug_siege and seat_area:
		print("[SiegePilote] seat_area layer=", seat_area.collision_layer, " mask=", seat_area.collision_mask)

	if debug_siege:
		print("[SiegePilote] READY parent=", get_parent(), " vehicule=", vehicule)
		print("[SiegePilote] action_interagir=", action_interagir)
		print("[SiegePilote] seat_area=", seat_area, " seat_marker=", seat_marker, " exit_marker=", exit_marker)
	if seat_area:
		if debug_siege:
			print("[SiegePilote] seat_area.monitoring=", seat_area.monitoring, " monitorable=", seat_area.monitorable)
		seat_area.body_entered.connect(_on_body_entered)
		seat_area.body_exited.connect(_on_body_exited)
	else:
		if debug_siege:
			print("[SiegePilote] ERREUR: seat_area null (chemin_seat_area invalide)")

func _process(_dt: float) -> void:
	if not Input.is_action_just_pressed(action_interagir):
		return

	if debug_siege:
		print("[SiegePilote] INPUT ->", action_interagir, " conducteur=", conducteur, " candidat=", _candidat)

	if conducteur != null:
		_sortir()
	elif _candidat != null:
		_entrer(_candidat)
	else:
		if debug_siege:
			print("[SiegePilote] Rien a faire: aucun candidat dans la zone")


func _on_body_entered(body: Node) -> void:
	if conducteur != null:
		if debug_siege:
			print("[SiegePilote] body_entered ignore (deja conducteur) body=", body)
		return

	if body is CharacterBody2D:
		_candidat = body as CharacterBody2D
		if debug_siege:
			print("[SiegePilote] body_entered -> candidat=", _candidat, " name=", _candidat.name, " layer=", _candidat.collision_layer, " mask=", _candidat.collision_mask)
	else:
		if debug_siege:
			print("[SiegePilote] body_entered non CharacterBody2D ->", body)

func _on_body_exited(body: Node) -> void:
	if body == _candidat:
		if debug_siege:
			print("[SiegePilote] body_exited -> candidat cleared body=", body)
		_candidat = null
	elif debug_siege:
		print("[SiegePilote] body_exited autre body=", body)

func _entrer(p: CharacterBody2D) -> void:
	if debug_siege:
		print("[SiegePilote] ENTER demande -> p=", p, " seat_marker=", seat_marker, " vehicule=", vehicule)

	if p == null or not is_instance_valid(p):
		if debug_siege:
			print("[SiegePilote] ENTER abort: p invalide")
		return
	if vehicule == null or seat_marker == null:
		if debug_siege:
			print("[SiegePilote] ENTER abort: vehicule ou seat_marker null")
		return

	conducteur = p
	_parent_conducteur = conducteur.get_parent()

	_driver_layer = conducteur.collision_layer
	_driver_mask = conducteur.collision_mask
	_driver_physics_on = conducteur.is_physics_processing()

	if debug_siege:
		print("[SiegePilote] ENTER ok: parent_avant=", _parent_conducteur, " layer=", _driver_layer, " mask=", _driver_mask, " physics_on=", _driver_physics_on)

	conducteur.set_deferred("collision_layer", 0)
	conducteur.set_deferred("collision_mask", 0)
	conducteur.set_physics_process(false)
	conducteur.velocity = Vector2.ZERO
	if conducteur.has_method("set_controles_actifs"):
		conducteur.call("set_controles_actifs", false)

	conducteur.reparent(seat_marker, true)
	conducteur.position = Vector2.ZERO

	if vehicule.has_method("set_controle_actif"):
		vehicule.call("set_controle_actif", true)

	var gl = p.get("gestionnaire_loot")
	if gl != null and is_instance_valid(gl):
		if gl.has_method("on_entree_vehicule"):
			if debug_siege:
				print("[SiegePilote] Carburant -> on_entree_vehicule() vehicule=", vehicule, " stock=", gl.get("carburant_stocke"))
			gl.call("on_entree_vehicule", vehicule)
		elif gl.has_method("transferer_carburant_vers_vehicule"):
			if debug_siege:
				print("[SiegePilote] Carburant -> transferer_carburant_vers_vehicule() vehicule=", vehicule, " stock=", gl.get("carburant_stocke"))
			gl.call("transferer_carburant_vers_vehicule", vehicule)
	else:
		if debug_siege:
			print("[SiegePilote] Carburant -> gestionnaire_loot introuvable sur p")

	if debug_siege:
		print("[SiegePilote] ENTER fini: conducteur parent=", conducteur.get_parent(), " pos=", conducteur.global_position)

func _sortir() -> void:
	if debug_siege:
		print("[SiegePilote] EXIT demande conducteur=", conducteur, " vehicule=", vehicule)

	if conducteur == null or vehicule == null:
		if debug_siege:
			print("[SiegePilote] EXIT abort: conducteur ou vehicule null")
		return

	var p: CharacterBody2D = conducteur
	conducteur = null

	if vehicule.has_method("set_controle_actif"):
		vehicule.call("set_controle_actif", false)

	if _parent_conducteur != null and is_instance_valid(_parent_conducteur):
		p.reparent(_parent_conducteur, true)
	else:
		p.reparent(get_tree().current_scene, true)

	p.set_physics_process(_driver_physics_on)
	p.set_deferred("collision_layer", _driver_layer)
	p.set_deferred("collision_mask", _driver_mask)
	if p.has_method("set_controles_actifs"):
		p.call("set_controles_actifs", true)

	var sortie_pos: Vector2
	if exit_marker != null:
		sortie_pos = exit_marker.global_position
	else:
		sortie_pos = vehicule.global_position + Vector2.RIGHT * 32.0
	p.global_position = sortie_pos

	if debug_siege:
		print("[SiegePilote] EXIT fini: parent=", p.get_parent(), " pos=", p.global_position, " layer=", _driver_layer, " mask=", _driver_mask)
