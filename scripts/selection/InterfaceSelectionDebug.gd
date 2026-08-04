extends CanvasLayer
class_name InterfaceSelectionDebug

@export var chemin_gestionnaire_selection: NodePath
@export var chemin_peur: NodePath

@onready var gestionnaire_selection: GestionnaireSelection = get_node_or_null(chemin_gestionnaire_selection) as GestionnaireSelection
@onready var peur: PeurSelectionPlaceholder = get_node_or_null(chemin_peur) as PeurSelectionPlaceholder
@onready var etiquette_debug: Label = $PanneauDebug/Informations
@onready var etiquette_evaluation: Label = $PanneauEvaluation/Resultat
@onready var panneau_evaluation: ColorRect = $PanneauEvaluation

func _ready() -> void:
	panneau_evaluation.visible = false
	if gestionnaire_selection != null:
		gestionnaire_selection.selection_demarre.connect(_actualiser)
		gestionnaire_selection.etape_changee.connect(_quand_etape_change)
		gestionnaire_selection.selection_terminee.connect(_quand_selection_terminee)
	if peur != null:
		peur.peur_changee.connect(_quand_peur_changee)
	_actualiser()

func _quand_etape_change(etape: GestionnaireSelection.Etape) -> void:
	_actualiser()
	if etape == GestionnaireSelection.Etape.EVALUATION:
		_afficher_evaluation()

func _quand_peur_changee(_valeur: float) -> void:
	_actualiser()

func _quand_selection_terminee() -> void:
	_actualiser()
	_afficher_evaluation()

func _actualiser() -> void:
	if gestionnaire_selection == null:
		return
	var donnees: DonneesSelection = gestionnaire_selection.donnees_selection
	var nom_etape: String = GestionnaireSelection.Etape.keys()[gestionnaire_selection.obtenir_etape_actuelle()]
	var esprits_restants: int = donnees.esprits_initiaux - donnees.esprits_perdus if donnees != null else 3
	var peur_actuelle: float = peur.peur_actuelle if peur != null else 0.0
	var peur_maximale: float = donnees.peur_maximale if donnees != null else 0.0
	etiquette_debug.text = "Etape : %s\nEsprits : %d\nPeur : %.0f\nPeur max : %.0f" % [nom_etape, esprits_restants, peur_actuelle, peur_maximale]

func _afficher_evaluation() -> void:
	if gestionnaire_selection == null or gestionnaire_selection.donnees_selection == null:
		return
	var donnees: DonneesSelection = gestionnaire_selection.donnees_selection
	panneau_evaluation.visible = true
	etiquette_evaluation.text = "SELECTION TERMINEE\n\nEsprits perdus : %d\nPeur maximale : %.0f\nDegats recus : %.0f\nPieges : %d\nTirs : %d / %d\n\nDecision : REFUS" % [donnees.esprits_perdus, donnees.peur_maximale, donnees.degats_recus, donnees.pieges_declenches, donnees.tirs_reussis, donnees.tirs_effectues]
