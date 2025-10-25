extends Node

@export var scene_jeu: PackedScene
@export var scene_options: PackedScene
@export var scene_credits: PackedScene

var menu: MenuTitre

func _ready() -> void:
	if get_parent() is MenuTitre:
		menu = get_parent() as MenuTitre
	else:
		push_error("GestionnaireMenuTitre doit être enfant du MenuTitre.")
		return

	menu.demande_jouer.connect(_sur_demande_jouer)
	menu.demande_parametres.connect(_sur_demande_parametres)
	menu.demande_credits.connect(_sur_demande_credits)
	menu.demande_quitter.connect(_sur_demande_quitter)

func _sur_demande_jouer() -> void:
	if scene_jeu == null:
		push_error("Aucune scène de jeu définie.")
		return
	# Enregistre la scène courante et charge la nouvelle
	GestionnaireRetour.aller_a_scene(scene_jeu)

func _sur_demande_parametres() -> void:
	if scene_options == null:
		push_error("Aucune scène d’options définie.")
		return
	GestionnaireRetour.aller_a_scene(scene_options)

func _sur_demande_credits() -> void:
	if scene_credits == null:
		push_error("Aucune scène de crédits définie.")
		return
	GestionnaireRetour.aller_a_scene(scene_credits)

func _sur_demande_quitter() -> void:
	get_tree().quit()
