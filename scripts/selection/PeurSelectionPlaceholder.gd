extends Node
class_name PeurSelectionPlaceholder

signal peur_changee(valeur: float)

@export var peur_maximale_possible: float = 100.0

var peur_actuelle: float = 0.0

func definir_peur(valeur: float) -> void:
	peur_actuelle = clampf(valeur, 0.0, peur_maximale_possible)
	peur_changee.emit(peur_actuelle)
