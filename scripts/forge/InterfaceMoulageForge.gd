extends CanvasLayer
class_name InterfaceMoulageForge

const RESULTAT_ECHEC: StringName = &"echec"

@export_node_path("GestionnaireForge") var chemin_gestionnaire_forge: NodePath
@export_node_path("GestionnaireMoulage") var chemin_gestionnaire_moulage: NodePath

@onready var gestionnaire_forge: GestionnaireForge = get_node_or_null(chemin_gestionnaire_forge) as GestionnaireForge
@onready var gestionnaire_moulage: GestionnaireMoulage = get_node_or_null(chemin_gestionnaire_moulage) as GestionnaireMoulage
@onready var interface: Control = $Interface
@onready var zone_moulage: ZoneMoulage = $Interface/Panneau/Marge/Colonne/ZoneMoulage
@onready var progression: ProgressBar = $Interface/Panneau/Marge/Colonne/Progression
@onready var matiere_fondue: ProgressBar = $Interface/Panneau/Marge/Colonne/MatiereFondue
@onready var point_actuel: Label = $Interface/Panneau/Marge/Colonne/PointActuel
@onready var indication: Label = $Interface/Panneau/Marge/Colonne/Indication
@onready var resultat: Label = $Interface/Panneau/Marge/Colonne/Resultat
@onready var bouton_action: Button = $Interface/Panneau/Marge/Colonne/BoutonAction
@onready var bouton_valider: Button = $Interface/Panneau/Marge/Colonne/BoutonValider
@onready var bouton_quitter: Button = $Interface/Panneau/Marge/Colonne/BoutonQuitter

var en_cours: bool = false
var dernier_resultat: StringName = &""
var mode_souris_precedent: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var mode_souris_modifie: bool = false

func _ready() -> void:
	interface.hide()
	set_process(false)
	bouton_action.pressed.connect(_action_resultat)
	bouton_valider.pressed.connect(_valider_resultat)
	bouton_quitter.pressed.connect(_quitter)
	if gestionnaire_moulage == null:
		push_error("GestionnaireMoulage introuvable. Verifie chemin_gestionnaire_moulage dans InterfaceMoulageForge.")
		return
	zone_moulage.definir_gestionnaire(gestionnaire_moulage)
	gestionnaire_moulage.moulage_actualise.connect(_rafraichir)
	gestionnaire_moulage.moulage_termine.connect(_quand_moulage_termine)
	if gestionnaire_forge == null:
		push_error("GestionnaireForge introuvable. Verifie chemin_gestionnaire_forge dans InterfaceMoulageForge.")

func _process(delta: float) -> void:
	gestionnaire_moulage.mettre_a_jour(delta)

func _input(event: InputEvent) -> void:
	if not en_cours or not event is InputEventMouseMotion:
		return
	var mouvement: InputEventMouseMotion = event as InputEventMouseMotion
	if zone_moulage.size.x <= 0.0 or zone_moulage.size.y <= 0.0:
		return
	gestionnaire_moulage.definir_position_curseur((mouvement.position - zone_moulage.get_global_rect().position) / zone_moulage.size)
	get_viewport().set_input_as_handled()

func ouvrir() -> bool:
	if gestionnaire_forge == null or gestionnaire_moulage == null or gestionnaire_forge.fabrication_active == null:
		return false
	if not gestionnaire_moulage.demarrer(gestionnaire_forge.fabrication_active.difficulte):
		return false
	interface.show()
	en_cours = true
	dernier_resultat = &""
	resultat.text = ""
	indication.text = "Maintiens le curseur dans le point actif."
	bouton_action.hide()
	bouton_valider.hide()
	if not mode_souris_modifie:
		mode_souris_precedent = Input.mouse_mode
		mode_souris_modifie = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	call_deferred("_initialiser_position_souris")
	set_process(true)
	_rafraichir()
	return true

func _initialiser_position_souris() -> void:
	if not en_cours or zone_moulage.size.x <= 0.0 or zone_moulage.size.y <= 0.0:
		return
	gestionnaire_moulage.definir_position_curseur((get_viewport().get_mouse_position() - zone_moulage.get_global_rect().position) / zone_moulage.size)

func fermer() -> void:
	en_cours = false
	if gestionnaire_moulage != null:
		gestionnaire_moulage.actif = false
	set_process(false)
	interface.hide()
	_restaurer_mode_souris()

func _restaurer_mode_souris() -> void:
	if not mode_souris_modifie:
		return
	Input.mouse_mode = mode_souris_precedent
	mode_souris_modifie = false

func _rafraichir() -> void:
	progression.value = gestionnaire_moulage.obtenir_progression() * 100.0
	matiere_fondue.value = gestionnaire_moulage.obtenir_matiere_fondue()
	point_actuel.text = "Point : %d/%d" % [mini(gestionnaire_moulage.index_point_actuel + 1, gestionnaire_moulage.nombre_points_actuel), gestionnaire_moulage.nombre_points_actuel]
	zone_moulage.rafraichir()

func _quand_moulage_termine(nouveau_resultat: StringName) -> void:
	en_cours = false
	dernier_resultat = nouveau_resultat
	set_process(false)
	if nouveau_resultat == RESULTAT_ECHEC:
		resultat.text = "Resultat : ECHEC | Score : %d%%" % roundi(gestionnaire_moulage.obtenir_score_final() * 100.0)
		indication.text = "Tu peux recommencer sans perdre les materiaux."
		bouton_action.text = "Recommencer"
		bouton_valider.hide()
	else:
		resultat.text = "Resultat : %s | Score : %d%%" % [String(nouveau_resultat).to_upper(), roundi(gestionnaire_moulage.obtenir_score_final() * 100.0)]
		indication.text = "Resultat pret. Valide-le ou essaie de faire mieux."
		bouton_action.text = "Reessayer"
		bouton_valider.show()
	bouton_action.show()

func _action_resultat() -> void:
	ouvrir()

func _valider_resultat() -> void:
	if gestionnaire_forge == null or dernier_resultat == &"" or dernier_resultat == RESULTAT_ECHEC:
		return
	gestionnaire_forge.terminer_moulage(dernier_resultat)
	gestionnaire_forge.fermer_interfaces_forge()

func _quitter() -> void:
	if gestionnaire_forge != null:
		gestionnaire_forge.abandonner_fabrication_active()
	else:
		fermer()

func _exit_tree() -> void:
	_restaurer_mode_souris()
