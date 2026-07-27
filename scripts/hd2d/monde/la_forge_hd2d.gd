class_name LaForgeHD2D
extends Node3D

@export var environnement: Environment

func _ready() -> void:
	if environnement != null and GestionnaireGraphisme.has_method("utiliser_environment_scene"):
		GestionnaireGraphisme.utiliser_environment_scene(environnement)

func _exit_tree() -> void:
	if GestionnaireGraphisme.has_method("liberer_environment_scene"):
		GestionnaireGraphisme.liberer_environment_scene(environnement)
