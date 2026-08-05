extends Node
class_name GestionnaireEspritsAspirant

@export var position_relative_etat_emotionnel: Vector2 = Vector2(-160.0, -80.0):
	set(nouvelle_position):
		position_relative_etat_emotionnel = nouvelle_position
		_appliquer_position_relative(0, nouvelle_position)
@export var position_relative_aptitude_physique: Vector2 = Vector2(-210.0, 0.0):
	set(nouvelle_position):
		position_relative_aptitude_physique = nouvelle_position
		_appliquer_position_relative(1, nouvelle_position)
@export var position_relative_capacites_cognitives: Vector2 = Vector2(-160.0, 80.0):
	set(nouvelle_position):
		position_relative_capacites_cognitives = nouvelle_position
		_appliquer_position_relative(2, nouvelle_position)

var esprits: Array[EspritAspirant] = []

func _ready() -> void:
	_referencer_esprits()

func initialiser(joueur: Node2D) -> void:
	if not is_instance_valid(joueur):
		push_error("GestionnaireEspritsAspirant: joueur absent.")
		return
	_referencer_esprits()
	if esprits.size() != 3:
		push_error("GestionnaireEspritsAspirant: exactement trois esprits sont requis.")
		return
	for esprit: EspritAspirant in esprits:
		esprit.definir_proprietaire(joueur)
	_appliquer_positions_relatives()

func obtenir_nombre_esprits() -> int:
	return esprits.size()

func obtenir_esprits() -> Array[EspritAspirant]:
	return esprits.duplicate()

func _referencer_esprits() -> void:
	esprits.clear()
	for enfant: Node in get_children():
		if enfant is EspritAspirant:
			esprits.append(enfant as EspritAspirant)

func _appliquer_positions_relatives() -> void:
	_appliquer_position_relative(0, position_relative_etat_emotionnel)
	_appliquer_position_relative(1, position_relative_aptitude_physique)
	_appliquer_position_relative(2, position_relative_capacites_cognitives)

func _appliquer_position_relative(index: int, nouvelle_position: Vector2) -> void:
	if index < 0 or index >= esprits.size():
		return
	esprits[index].definir_decalage(nouvelle_position)
