extends Node
class_name GestionnaireModesDeplacement

enum ModeDeplacement {
	LIBRE,
	COMBAT
}

@export var mode_par_defaut: ModeDeplacement = ModeDeplacement.LIBRE
var mode_actuel: ModeDeplacement = ModeDeplacement.LIBRE

func _ready() -> void:
	mode_actuel = mode_par_defaut

func definir_mode(nouveau_mode: ModeDeplacement) -> void:
	mode_actuel = nouveau_mode

func activer_mode_libre() -> void:
	definir_mode(ModeDeplacement.LIBRE)

func activer_mode_combat() -> void:
	definir_mode(ModeDeplacement.COMBAT)

func est_en_mode_combat() -> bool:
	return mode_actuel == ModeDeplacement.COMBAT
