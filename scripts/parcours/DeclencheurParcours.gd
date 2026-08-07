extends ElementParcours
class_name DeclencheurParcours

signal declenche(joueur: CharacterBody2D)

@export var activation_unique: bool = true

var _deja_declenche: bool = false

func activer(joueur: CharacterBody2D, _gestionnaire) -> void:
	if activation_unique and _deja_declenche:
		return
	_deja_declenche = true
	declenche.emit(joueur)
