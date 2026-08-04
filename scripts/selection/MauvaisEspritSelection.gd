extends Node2D
class_name MauvaisEspritSelection

signal destination_atteinte

enum Etat {
	ATTENTE,
	FUITE
}

@export var vitesse_fuite: float = 700.0
@export var distance_arrivee: float = 8.0

var etat: Etat = Etat.ATTENTE
var destination: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	if etat != Etat.FUITE:
		return
	if global_position.distance_to(destination) <= distance_arrivee:
		global_position = destination
		arreter()
		destination_atteinte.emit()
		return
	global_position = global_position.move_toward(destination, vitesse_fuite * delta)

func fuir_vers(nouvelle_destination: Vector2) -> void:
	destination = nouvelle_destination
	etat = Etat.FUITE

func arreter() -> void:
	etat = Etat.ATTENTE

func est_en_fuite() -> bool:
	return etat == Etat.FUITE
