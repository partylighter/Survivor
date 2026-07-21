extends Node
class_name ControleAttaquesArmes

@export_node_path("GestionnaireArme") var chemin_gestionnaire: NodePath
@export var tir_manuel_maintenu: bool = true
var gestionnaire: GestionnaireArme

var auto_droite: bool = false
var auto_gauche: bool = false

func _ready() -> void:
	add_to_group(&"inputs_jeu")
	gestionnaire = get_node_or_null(chemin_gestionnaire) as GestionnaireArme

func _process(_dt: float) -> void:
	if gestionnaire == null:
		return
	if tir_manuel_maintenu:
		_gerer_tir_manuel()
		return

	if Input.is_action_just_pressed("attaque_main_droite"):
		auto_droite = not auto_droite
	if Input.is_action_just_pressed("attaque_main_gauche"):
		if not gestionnaire.arme_unique:
			auto_gauche = not auto_gauche

	if auto_droite:
		var a: ArmeBase = gestionnaire.arme_principale
		if is_instance_valid(a) and a.peut_attaquer():
			a.attaquer()
	if auto_gauche and not gestionnaire.arme_unique:
		var b: ArmeBase = gestionnaire.arme_secondaire
		if is_instance_valid(b) and b.peut_attaquer():
			b.attaquer()

func _gerer_tir_manuel() -> void:
	_gerer_entree_manuelle(&"attaque_main_droite", gestionnaire.arme_principale)
	if not gestionnaire.arme_unique:
		_gerer_entree_manuelle(&"attaque_main_gauche", gestionnaire.arme_secondaire)

func _gerer_entree_manuelle(action: StringName, arme: ArmeBase) -> void:
	if not is_instance_valid(arme):
		return
	if Input.is_action_just_pressed(action):
		if arme.has_method("commencer_charge"):
			arme.call("commencer_charge")
	if Input.is_action_just_released(action):
		if arme.has_method("relacher_charge"):
			arme.call("relacher_charge")
		elif arme.peut_attaquer():
			arme.attaquer()
