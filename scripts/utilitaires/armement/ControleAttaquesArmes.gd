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
	auto_droite = _gerer_entree(&"attaque_main_droite", gestionnaire.arme_principale, auto_droite)
	if not gestionnaire.arme_unique:
		auto_gauche = _gerer_entree(&"attaque_main_gauche", gestionnaire.arme_secondaire, auto_gauche)

func _gerer_entree(action: StringName, arme: ArmeBase, mode_auto: bool) -> bool:
	if not is_instance_valid(arme):
		return false

	var arme_tir: ArmeTir = arme as ArmeTir
	if arme_tir != null and arme_tir.tir_manuel_maintenu:
		if Input.is_action_just_pressed(action):
			arme_tir.commencer_charge()
		if Input.is_action_just_released(action):
			arme_tir.relacher_charge()
		return false

	if Input.is_action_just_pressed(action):
		mode_auto = not mode_auto
	if mode_auto and arme.peut_attaquer():
			arme.attaquer()
	return mode_auto
