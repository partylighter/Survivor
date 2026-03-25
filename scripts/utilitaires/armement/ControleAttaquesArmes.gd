extends Node
class_name ControleAttaquesArmes

@export_node_path("GestionnaireArme") var chemin_gestionnaire: NodePath
var gestionnaire: GestionnaireArme

var auto_droite: bool = false
var auto_gauche: bool = false

func _ready() -> void:
	add_to_group(&"inputs_jeu")
	gestionnaire = get_node_or_null(chemin_gestionnaire) as GestionnaireArme

func _process(_dt: float) -> void:
	if gestionnaire == null:
		return

	if Input.is_action_just_pressed("attaque_main_droite"):
		auto_droite = not auto_droite
	if Input.is_action_just_pressed("attaque_main_gauche"):
		auto_gauche = not auto_gauche

	if auto_droite:
		var a: ArmeBase = gestionnaire.arme_principale
		if is_instance_valid(a) and a.peut_attaquer():
			a.attaquer()
	if auto_gauche:
		var b: ArmeBase = gestionnaire.arme_secondaire
		if is_instance_valid(b) and b.peut_attaquer():
			b.attaquer()
