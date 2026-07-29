extends CanvasLayer
class_name InterfaceFonteForge

@export_node_path("GestionnaireForge") var chemin_gestionnaire_forge: NodePath
@export_node_path("GestionnaireFonte") var chemin_gestionnaire_fonte: NodePath

@onready var gestionnaire_forge: GestionnaireForge = get_node_or_null(chemin_gestionnaire_forge) as GestionnaireForge
@onready var gestionnaire_fonte: GestionnaireFonte = get_node_or_null(chemin_gestionnaire_fonte) as GestionnaireFonte
@onready var interface: Control = $Interface
@onready var jauge: JaugeChauffe = $Interface/Panneau/Marge/Colonne/Jauge
@onready var temperature: Label = $Interface/Panneau/Marge/Colonne/Temperature
@onready var niveau: Label = $Interface/Panneau/Marge/Colonne/Niveau
@onready var maintien: ProgressBar = $Interface/Panneau/Marge/Colonne/Maintien
@onready var temps_restant: Label = $Interface/Panneau/Marge/Colonne/TempsRestant
@onready var temps: ProgressBar = $Interface/Panneau/Marge/Colonne/Temps
@onready var indication: Label = $Interface/Panneau/Marge/Colonne/Indication
@onready var resultat: Label = $Interface/Panneau/Marge/Colonne/Resultat
@onready var bouton_action: Button = $Interface/Panneau/Marge/Colonne/BoutonAction
@onready var bouton_valider: Button = $Interface/Panneau/Marge/Colonne/BoutonValider
@onready var bouton_quitter: Button = $Interface/Panneau/Marge/Colonne/BoutonQuitter

var en_cours: bool = false
var clic_maintenu: bool = false
var dernier_resultat: StringName = &""

func _ready() -> void:
	interface.hide()
	set_process(false)
	if gestionnaire_fonte == null:
		push_error("GestionnaireFonte introuvable. Verifie chemin_gestionnaire_fonte dans InterfaceFonteForge.")
		return
	gestionnaire_fonte.fonte_actualisee.connect(_rafraichir)
	gestionnaire_fonte.fonte_terminee.connect(_quand_fonte_terminee)
	bouton_action.pressed.connect(_action_resultat)
	bouton_valider.pressed.connect(_valider_resultat)
	bouton_quitter.pressed.connect(_quitter)
	if gestionnaire_forge == null:
		push_error("GestionnaireForge introuvable. Verifie chemin_gestionnaire_forge dans InterfaceFonteForge.")

func _process(delta: float) -> void:
	gestionnaire_fonte.mettre_a_jour(delta, clic_maintenu)

func _input(event: InputEvent) -> void:
	if not en_cours or not event is InputEventMouseButton:
		return
	var clic: InputEventMouseButton = event as InputEventMouseButton
	if clic.button_index != MOUSE_BUTTON_LEFT:
		return
	if clic.pressed and bouton_quitter.get_global_rect().has_point(clic.position):
		_quitter()
		get_viewport().set_input_as_handled()
		return
	if clic.pressed and bouton_action.visible and bouton_action.get_global_rect().has_point(clic.position):
		_action_resultat()
		get_viewport().set_input_as_handled()
		return
	clic_maintenu = clic.pressed
	get_viewport().set_input_as_handled()

func ouvrir() -> bool:
	if gestionnaire_forge == null or gestionnaire_forge.fabrication_active == null:
		return false
	if not gestionnaire_fonte.demarrer(gestionnaire_forge.fabrication_active.difficulte):
		return false
	interface.show()
	en_cours = true
	clic_maintenu = false
	dernier_resultat = &""
	resultat.text = ""
	indication.text = "Maintiens le clic pour chauffer, relache pour faire redescendre."
	bouton_action.hide()
	bouton_valider.hide()
	set_process(true)
	_rafraichir()
	return true

func fermer() -> void:
	en_cours = false
	clic_maintenu = false
	gestionnaire_fonte.actif = false
	set_process(false)
	interface.hide()

func _rafraichir() -> void:
	jauge.actualiser(gestionnaire_fonte.temperature_actuelle, gestionnaire_fonte.obtenir_limite_basse(), gestionnaire_fonte.obtenir_limite_haute(), gestionnaire_fonte.obtenir_limite_correcte_basse(), gestionnaire_fonte.obtenir_limite_correcte_haute(), gestionnaire_fonte.obtenir_limite_tolerance_basse(), gestionnaire_fonte.obtenir_limite_tolerance_haute())
	temperature.text = "Temperature : %.1f" % gestionnaire_fonte.temperature_actuelle
	niveau.text = "Niveau %d/%d - cible : %.0f" % [mini(gestionnaire_fonte.index_niveau + 1, gestionnaire_fonte.niveaux_a_maintenir.size()), gestionnaire_fonte.niveaux_a_maintenir.size(), gestionnaire_fonte.obtenir_niveau_cible()]
	maintien.value = gestionnaire_fonte.obtenir_progression_maintien() * 100.0
	temps_restant.text = "Temps restant : %.1f s" % gestionnaire_fonte.obtenir_temps_restant()
	temps.value = gestionnaire_fonte.obtenir_progression_temps() * 100.0

func _quand_fonte_terminee(nouveau_resultat: StringName) -> void:
	en_cours = false
	clic_maintenu = false
	dernier_resultat = nouveau_resultat
	set_process(false)
	if nouveau_resultat == GestionnaireFonte.RESULTAT_ECHEC:
		resultat.text = "Resultat : ECHEC"
		indication.text = "Tu peux recommencer sans perdre les materiaux."
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
	if gestionnaire_forge == null or dernier_resultat == &"" or dernier_resultat == GestionnaireFonte.RESULTAT_ECHEC:
		return
	gestionnaire_forge.terminer_fonte(dernier_resultat)
	gestionnaire_forge.fermer_interfaces_forge()

func _quitter() -> void:
	if gestionnaire_forge != null:
		gestionnaire_forge.abandonner_fabrication_active()
	else:
		fermer()
