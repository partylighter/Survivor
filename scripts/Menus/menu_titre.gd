extends CanvasLayer
class_name MenuTitre

signal demande_jouer
signal demande_parametres
signal demande_credits
signal demande_quitter

@export_node_path("Button") var chemin_btn_jouer: NodePath
@export_node_path("Button") var chemin_btn_parametres: NodePath
@export_node_path("Button") var chemin_btn_credits: NodePath
@export_node_path("Button") var chemin_btn_quitter: NodePath

var btn_jouer: Button
var btn_parametres: Button
var btn_credits: Button
var btn_quitter: Button

func _ready() -> void:
	# Récupération des boutons via les NodePaths exportés,
	# avec fallback vers la recherche par nom si les chemins ne sont pas renseignés.
	btn_jouer      = get_node_or_null(chemin_btn_jouer)      as Button
	if btn_jouer == null:      btn_jouer      = find_child("btn_play",    true, false) as Button
	btn_parametres = get_node_or_null(chemin_btn_parametres) as Button
	if btn_parametres == null: btn_parametres = find_child("btn_settings", true, false) as Button
	btn_credits    = get_node_or_null(chemin_btn_credits)    as Button
	if btn_credits == null:    btn_credits    = find_child("btn_credits", true, false) as Button
	btn_quitter    = get_node_or_null(chemin_btn_quitter)    as Button
	if btn_quitter == null:    btn_quitter    = find_child("btn_quit",    true, false) as Button

	# Connexion des signaux des boutons au menu
	if btn_jouer:      btn_jouer.pressed.connect(_on_jouer)
	if btn_parametres: btn_parametres.pressed.connect(_on_parametres)
	if btn_credits:    btn_credits.pressed.connect(_on_credits)
	if btn_quitter:    btn_quitter.pressed.connect(_on_quitter)

func _on_jouer() -> void:      demande_jouer.emit()
func _on_parametres() -> void: demande_parametres.emit()
func _on_credits() -> void:    demande_credits.emit()
func _on_quitter() -> void:    demande_quitter.emit()
