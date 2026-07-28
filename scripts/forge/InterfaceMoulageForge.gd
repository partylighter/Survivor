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
@onready var point_actuel: Label = $Interface/Panneau/Marge/Colonne/PointActuel
@onready var indication: Label = $Interface/Panneau/Marge/Colonne/Indication
@onready var resultat: Label = $Interface/Panneau/Marge/Colonne/Resultat
@onready var bouton_action: Button = $Interface/Panneau/Marge/Colonne/BoutonAction

var en_cours: bool = false
var dernier_resultat: StringName = &""
var mode_souris_avant: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var souris_capturee: bool = false

func _ready() -> void:
	interface.hide()
	set_process(false)
	if gestionnaire_moulage == null:
		push_error("GestionnaireMoulage introuvable. Verifie chemin_gestionnaire_moulage dans InterfaceMoulageForge.")
		return
	zone_moulage.definir_gestionnaire(gestionnaire_moulage)
	gestionnaire_moulage.moulage_actualise.connect(_rafraichir)
	gestionnaire_moulage.moulage_termine.connect(_quand_moulage_termine)
	bouton_action.pressed.connect(_action_resultat)
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
	gestionnaire_moulage.deplacer_curseur(Vector2(mouvement.relative.x / zone_moulage.size.x, mouvement.relative.y / zone_moulage.size.y))
	get_viewport().set_input_as_handled()

func ouvrir() -> bool:
	if gestionnaire_forge == null or gestionnaire_forge.fabrication_active == null:
		return false
	if not gestionnaire_moulage.demarrer(gestionnaire_forge.fabrication_active.difficulte):
		return false
	interface.show()
	en_cours = true
	dernier_resultat = &""
	resultat.text = ""
	indication.text = "Maintiens le curseur dans le point orange et resiste aux tremblements."
	bouton_action.hide()
	mode_souris_avant = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	souris_capturee = true
	set_process(true)
	_rafraichir()
	return true

func fermer() -> void:
	en_cours = false
	gestionnaire_moulage.actif = false
	set_process(false)
	if souris_capturee:
		Input.mouse_mode = mode_souris_avant
		souris_capturee = false
	interface.hide()

func _rafraichir() -> void:
	progression.value = gestionnaire_moulage.obtenir_progression() * 100.0
	point_actuel.text = "Point : %d/%d" % [mini(gestionnaire_moulage.index_point_actuel + 1, gestionnaire_moulage.nombre_points_actuel), gestionnaire_moulage.nombre_points_actuel]
	zone_moulage.queue_redraw()

func _quand_moulage_termine(nouveau_resultat: StringName) -> void:
	en_cours = false
	dernier_resultat = nouveau_resultat
	set_process(false)
	if souris_capturee:
		Input.mouse_mode = mode_souris_avant
		souris_capturee = false
	if gestionnaire_forge != null:
		gestionnaire_forge.terminer_moulage(nouveau_resultat)
	if nouveau_resultat == RESULTAT_ECHEC:
		resultat.text = "Resultat : ECHEC"
		indication.text = "Tu peux recommencer sans perdre les materiaux."
		bouton_action.text = "Recommencer"
	else:
		resultat.text = "Resultat : %s" % String(nouveau_resultat).to_upper()
		indication.text = "Composant ajoute a l'inventaire."
		bouton_action.text = "Fermer"
	bouton_action.show()

func _action_resultat() -> void:
	if dernier_resultat == RESULTAT_ECHEC:
		ouvrir()
	elif gestionnaire_forge != null:
		gestionnaire_forge.fermer_interfaces_forge()
	else:
		fermer()

func _exit_tree() -> void:
	if souris_capturee:
		Input.mouse_mode = mode_souris_avant
