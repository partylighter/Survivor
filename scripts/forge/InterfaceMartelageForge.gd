extends CanvasLayer
class_name InterfaceMartelageForge

@export_node_path("GestionnaireForge") var chemin_gestionnaire_forge: NodePath
@export_node_path("GestionnaireMartelage") var chemin_gestionnaire_martelage: NodePath

@onready var gestionnaire_forge: GestionnaireForge = get_node_or_null(chemin_gestionnaire_forge) as GestionnaireForge
@onready var gestionnaire_martelage: GestionnaireMartelage = get_node_or_null(chemin_gestionnaire_martelage) as GestionnaireMartelage
@onready var interface: Control = $Interface
@onready var zone_martelage: ZoneMartelage = $Interface/Panneau/Marge/Colonne/ZoneMartelage
@onready var progression: Label = $Interface/Panneau/Marge/Colonne/Progression
@onready var evaluation: Label = $Interface/Panneau/Marge/Colonne/Evaluation
@onready var resultat: Label = $Interface/Panneau/Marge/Colonne/Resultat
@onready var bouton_action: Button = $Interface/Panneau/Marge/Colonne/BoutonAction

var en_cours: bool = false
var dernier_resultat: StringName = &""

func _ready() -> void:
	interface.hide()
	set_process(false)
	if gestionnaire_martelage == null:
		push_error("GestionnaireMartelage introuvable. Verifie chemin_gestionnaire_martelage dans InterfaceMartelageForge.")
		return
	zone_martelage.definir_gestionnaire(gestionnaire_martelage)
	zone_martelage.clic_demande.connect(_enregistrer_clic)
	gestionnaire_martelage.martelage_actualise.connect(_rafraichir)
	gestionnaire_martelage.point_evalue.connect(_afficher_evaluation)
	gestionnaire_martelage.martelage_termine.connect(_quand_martelage_termine)
	bouton_action.pressed.connect(_action_resultat)
	if gestionnaire_forge == null:
		push_error("GestionnaireForge introuvable. Verifie chemin_gestionnaire_forge dans InterfaceMartelageForge.")

func _process(delta: float) -> void:
	gestionnaire_martelage.mettre_a_jour(delta)

func ouvrir() -> bool:
	if gestionnaire_forge == null or gestionnaire_forge.fabrication_active == null:
		return false
	if not gestionnaire_martelage.demarrer(gestionnaire_forge.fabrication_active.difficulte):
		return false
	interface.show()
	en_cours = true
	dernier_resultat = &""
	evaluation.text = "Clique lorsque le cercle blanc rejoint le point."
	resultat.text = ""
	bouton_action.hide()
	set_process(true)
	_rafraichir()
	return true

func fermer() -> void:
	en_cours = false
	gestionnaire_martelage.actif = false
	set_process(false)
	interface.hide()

func _enregistrer_clic(position_normalisee: Vector2) -> void:
	gestionnaire_martelage.enregistrer_clic(position_normalisee)

func _rafraichir() -> void:
	progression.text = "Points : %d/%d - Parfaits : %d - Corrects : %d - Rates : %d" % [gestionnaire_martelage.nombre_points_evalues, gestionnaire_martelage.nombre_points_actuel, gestionnaire_martelage.nombre_parfaits, gestionnaire_martelage.nombre_corrects, gestionnaire_martelage.nombre_rates + gestionnaire_martelage.penalites_clics_rates]
	zone_martelage.queue_redraw()

func _afficher_evaluation(nouvelle_evaluation: StringName) -> void:
	evaluation.text = "Evaluation : %s" % String(nouvelle_evaluation).to_upper()

func _quand_martelage_termine(nouveau_resultat: StringName) -> void:
	en_cours = false
	dernier_resultat = nouveau_resultat
	set_process(false)
	if gestionnaire_forge != null:
		gestionnaire_forge.terminer_martelage(nouveau_resultat)
	if nouveau_resultat == GestionnaireMartelage.RESULTAT_ECHEC:
		resultat.text = "Resultat : ECHEC"
		evaluation.text = "Tu peux recommencer sans perdre les materiaux."
		bouton_action.text = "Recommencer"
	else:
		resultat.text = "Resultat : %s" % String(nouveau_resultat).to_upper()
		evaluation.text = "Composant ajoute a l'inventaire."
		bouton_action.text = "Fermer"
	bouton_action.show()

func _action_resultat() -> void:
	if dernier_resultat == GestionnaireMartelage.RESULTAT_ECHEC:
		ouvrir()
	elif gestionnaire_forge != null:
		gestionnaire_forge.fermer_interfaces_forge()
	else:
		fermer()
