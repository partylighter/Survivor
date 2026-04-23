extends Node

const SCENE_JEU:     PackedScene = preload("res://scenes/niveaux/NiveauTest/world.tscn")
const SCENE_OPTIONS: PackedScene = preload("res://scenes/menus/menu_parametres.tscn")
const SCENE_CREDITS: PackedScene = preload("res://scenes/menus/menu_credits.tscn")

func _ready() -> void:
	var menu := get_parent() as MenuTitre
	if menu == null:
		push_error("GestionnaireMenuTitre doit être enfant du MenuTitre.")
		return

	menu.demande_jouer.connect(_sur_demande_jouer)
	menu.demande_parametres.connect(_sur_demande_parametres)
	menu.demande_credits.connect(_sur_demande_credits)
	menu.demande_quitter.connect(_sur_demande_quitter)

func _sur_demande_jouer() -> void:
	GestionnaireRetour.aller_a_scene(SCENE_JEU)

func _sur_demande_parametres() -> void:
	GestionnaireRetour.aller_a_scene(SCENE_OPTIONS)

func _sur_demande_credits() -> void:
	GestionnaireRetour.aller_a_scene(SCENE_CREDITS)

func _sur_demande_quitter() -> void:
	get_tree().quit()
