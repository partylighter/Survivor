extends CanvasLayer
class_name InterfaceChauffeForge

@export_node_path("GestionnaireForge") var chemin_gestionnaire_forge: NodePath
@export_node_path("GestionnaireChauffe") var chemin_gestionnaire_chauffe: NodePath

@onready var gestionnaire_forge: GestionnaireForge = get_node_or_null(chemin_gestionnaire_forge) as GestionnaireForge
@onready var gestionnaire_chauffe: GestionnaireChauffe = get_node_or_null(chemin_gestionnaire_chauffe) as GestionnaireChauffe
@onready var interface: Control = $Interface
@onready var jauge: JaugeChauffe = $Interface/Panneau/Marge/Colonne/Jauge
@onready var temperature: Label = $Interface/Panneau/Marge/Colonne/Temperature
@onready var niveau: Label = $Interface/Panneau/Marge/Colonne/Niveau
@onready var temps_restant: Label = $Interface/Panneau/Marge/Colonne/TempsRestant
@onready var maintien: Label = $Interface/Panneau/Marge/Colonne/Maintien
@onready var progression: ProgressBar = $Interface/Panneau/Marge/Colonne/Progression
@onready var etat_temperature: Label = $Interface/Panneau/Marge/Colonne/EtatTemperature
@onready var indication: Label = $Interface/Panneau/Marge/Colonne/Indication
@onready var resultat: Label = $Interface/Panneau/Marge/Colonne/Resultat
@onready var bouton_action: Button = $Interface/Panneau/Marge/Colonne/BoutonAction
@onready var bouton_valider: Button = $Interface/Panneau/Marge/Colonne/BoutonValider
@onready var bouton_quitter: Button = $Interface/Panneau/Marge/Colonne/BoutonQuitter

var en_cours: bool = false
var dernier_resultat: StringName = &""

func _ready() -> void:
	interface.hide()
	set_process(false)
	if gestionnaire_chauffe == null:
		push_error("GestionnaireChauffe introuvable. Verifie chemin_gestionnaire_chauffe dans InterfaceChauffeForge.")
		return
	gestionnaire_chauffe.chauffe_actualisee.connect(_rafraichir)
	gestionnaire_chauffe.chauffe_terminee.connect(_quand_chauffe_terminee)
	bouton_action.pressed.connect(_action_resultat)
	bouton_valider.pressed.connect(_valider_resultat)
	bouton_quitter.pressed.connect(_quitter)
	if gestionnaire_forge == null:
		push_error("GestionnaireForge introuvable. Verifie chemin_gestionnaire_forge dans InterfaceChauffeForge.")

func _process(delta: float) -> void:
	gestionnaire_chauffe.mettre_a_jour(delta)

func _input(event: InputEvent) -> void:
	if not en_cours or not event is InputEventMouseButton:
		return
	var clic: InputEventMouseButton = event as InputEventMouseButton
	if clic.button_index != MOUSE_BUTTON_LEFT or not clic.pressed:
		return
	if bouton_quitter.get_global_rect().has_point(clic.position):
		_quitter()
		get_viewport().set_input_as_handled()
		return
	if bouton_action.visible and bouton_action.get_global_rect().has_point(clic.position):
		_action_resultat()
		get_viewport().set_input_as_handled()
		return
	gestionnaire_chauffe.enregistrer_clic()
	get_viewport().set_input_as_handled()

func ouvrir() -> bool:
	if gestionnaire_forge == null or gestionnaire_forge.fabrication_active == null:
		return false
	if not gestionnaire_chauffe.demarrer(gestionnaire_forge.fabrication_active.difficulte):
		return false
	interface.show()
	en_cours = true
	dernier_resultat = &""
	resultat.text = ""
	bouton_action.hide()
	bouton_valider.hide()
	indication.text = "Clique rapidement pour monter, puis ralentis pour stabiliser dans la zone verte."
	set_process(true)
	_rafraichir()
	return true

func fermer() -> void:
	en_cours = false
	gestionnaire_chauffe.actif = false
	set_process(false)
	interface.hide()

func _rafraichir() -> void:
	jauge.actualiser(gestionnaire_chauffe.temperature_actuelle, gestionnaire_chauffe.obtenir_limite_basse(), gestionnaire_chauffe.obtenir_limite_haute(), gestionnaire_chauffe.obtenir_limite_correcte_basse(), gestionnaire_chauffe.obtenir_limite_correcte_haute(), gestionnaire_chauffe.obtenir_limite_tolerance_basse(), gestionnaire_chauffe.obtenir_limite_tolerance_haute())
	temperature.text = "Temperature : %.1f" % gestionnaire_chauffe.temperature_actuelle
	niveau.text = "Niveau %d/%d - cible : %.0f" % [mini(gestionnaire_chauffe.index_niveau + 1, gestionnaire_chauffe.niveaux_a_maintenir.size()), gestionnaire_chauffe.niveaux_a_maintenir.size(), gestionnaire_chauffe.obtenir_niveau_cible()]
	temps_restant.text = "Temps global : %.1f s" % gestionnaire_chauffe.obtenir_temps_restant()
	maintien.text = "Maintien : %.1f / %.1f s" % [gestionnaire_chauffe.progression_maintien, gestionnaire_chauffe.temps_maintien_requis]
	progression.value = gestionnaire_chauffe.obtenir_progression_maintien() * 100.0
	etat_temperature.text = "Etat : %s" % gestionnaire_chauffe.obtenir_nom_etat_temperature()

func _quand_chauffe_terminee(nouveau_resultat: StringName) -> void:
	en_cours = false
	dernier_resultat = nouveau_resultat
	set_process(false)
	if nouveau_resultat == GestionnaireChauffe.RESULTAT_ECHEC:
		resultat.text = "Resultat : ECHEC"
		indication.text = "Le materiau n'est pas perdu. Tu peux recommencer."
		bouton_action.text = "Recommencer"
		bouton_valider.hide()
	else:
		resultat.text = "Resultat : %s" % String(nouveau_resultat).to_upper()
		indication.text = "Resultat pret. Valide-le ou essaie de faire mieux."
		bouton_action.text = "Reessayer"
		bouton_valider.show()
	bouton_action.show()

func _action_resultat() -> void:
	ouvrir()

func _valider_resultat() -> void:
	if gestionnaire_forge == null or dernier_resultat == &"" or dernier_resultat == GestionnaireChauffe.RESULTAT_ECHEC:
		return
	gestionnaire_forge.terminer_chauffe(dernier_resultat)
	gestionnaire_forge.fermer_interfaces_forge()

func _quitter() -> void:
	if gestionnaire_forge != null:
		gestionnaire_forge.abandonner_fabrication_active()
	else:
		fermer()
