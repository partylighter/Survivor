extends Node2D
class_name VerticaleSelectionPlaceholder

@export var chemin_gestionnaire_selection: NodePath
@export var chemin_peur: NodePath
@export_node_path("Node2D") var chemin_mauvais_esprit: NodePath
@export_node_path("Node2D") var chemin_fragments: NodePath
@export_node_path("Node2D") var chemin_trace: NodePath
@export_node_path("Node2D") var chemin_boss: NodePath

@onready var gestionnaire_selection: GestionnaireSelection = get_node_or_null(chemin_gestionnaire_selection) as GestionnaireSelection
@onready var peur: PeurSelectionPlaceholder = get_node_or_null(chemin_peur) as PeurSelectionPlaceholder
@onready var mauvais_esprit: Node2D = get_node_or_null(chemin_mauvais_esprit) as Node2D
@onready var fragments: Node2D = get_node_or_null(chemin_fragments) as Node2D
@onready var trace: Node2D = get_node_or_null(chemin_trace) as Node2D
@onready var boss: Node2D = get_node_or_null(chemin_boss) as Node2D

func _ready() -> void:
	if gestionnaire_selection != null:
		gestionnaire_selection.etape_changee.connect(_quand_etape_change)
	if peur != null and gestionnaire_selection != null:
		peur.peur_changee.connect(gestionnaire_selection.enregistrer_peur)
	_actualiser_placeholders(GestionnaireSelection.Etape.PRESENTATION)

func _quand_etape_change(etape: GestionnaireSelection.Etape) -> void:
	_actualiser_placeholders(etape)

func _actualiser_placeholders(etape: GestionnaireSelection.Etape) -> void:
	if fragments != null:
		fragments.visible = etape == GestionnaireSelection.Etape.PREMIERE_POURSUITE or etape == GestionnaireSelection.Etape.DEUXIEME_CONFRONTATION
	if trace != null:
		trace.visible = etape == GestionnaireSelection.Etape.TRAQUE
	if boss != null:
		boss.visible = etape == GestionnaireSelection.Etape.BOSS
	if mauvais_esprit != null:
		mauvais_esprit.visible = etape < GestionnaireSelection.Etape.EVALUATION
		var marqueur: Marker2D = _obtenir_marqueur_mauvais_esprit(etape)
		if marqueur != null:
			mauvais_esprit.global_position = marqueur.global_position
	if etape == GestionnaireSelection.Etape.PEUR and peur != null:
		peur.definir_peur(75.0)

func _obtenir_marqueur_mauvais_esprit(etape: GestionnaireSelection.Etape) -> Marker2D:
	var nom_marqueur: String = "CiblePresentation"
	match etape:
		GestionnaireSelection.Etape.PREMIERE_POURSUITE:
			nom_marqueur = "CiblePremierePoursuite"
		GestionnaireSelection.Etape.TRAQUE:
			nom_marqueur = "CibleTraque"
		GestionnaireSelection.Etape.DEUXIEME_CONFRONTATION:
			nom_marqueur = "CibleConfrontation2"
		GestionnaireSelection.Etape.PEUR:
			nom_marqueur = "CiblePeur"
		GestionnaireSelection.Etape.DERNIERE_POURSUITE:
			nom_marqueur = "CibleDernierePoursuite"
		GestionnaireSelection.Etape.BOSS:
			nom_marqueur = "CibleBoss"
	return get_node_or_null("Parcours/CiblesMauvaisEsprit/%s" % nom_marqueur) as Marker2D
