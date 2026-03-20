extends Node
class_name Soif

signal changed(valeur_actuelle: float, valeur_max: float)
signal empty
signal died_of_thirst

@export var soif_max: float = 100.0
var soif: float = 0.0

func _ready() -> void:
	soif = soif_max
	emit_signal("changed", soif, soif_max)

func perdre_soif(amount: float) -> void:
	if amount <= 0.0:
		return
	
	soif = maxf(0.0, soif - amount)
	emit_signal("changed", soif, soif_max)
	
	if soif <= 0.0:
		emit_signal("empty")
		emit_signal("died_of_thirst")

func gagner_soif(amount: float) -> void:
	if amount <= 0.0:
		return
	soif = minf(soif_max, soif + amount)
	emit_signal("changed", soif, soif_max)
