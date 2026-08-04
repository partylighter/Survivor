extends Node
class_name GestionnaireEspritsAspirant

@export var decalages: Array[Vector2] = []

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
	if decalages.size() != 3:
		push_error("GestionnaireEspritsAspirant: exactement trois decalages sont requis.")
		return
	for index: int in range(esprits.size()):
		esprits[index].definir_proprietaire(joueur)
		esprits[index].definir_decalage(decalages[index])

func obtenir_nombre_esprits() -> int:
	return esprits.size()

func obtenir_esprits() -> Array[EspritAspirant]:
	return esprits.duplicate()

func _referencer_esprits() -> void:
	esprits.clear()
	for enfant: Node in get_children():
		if enfant is EspritAspirant:
			esprits.append(enfant as EspritAspirant)
