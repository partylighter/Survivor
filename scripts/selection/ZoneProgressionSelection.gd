extends Area2D
class_name ZoneProgressionSelection

@export var chemin_gestionnaire_selection: NodePath
@export var etape_requise: GestionnaireSelection.Etape = GestionnaireSelection.Etape.PRESENTATION
@export var prochaine_etape: GestionnaireSelection.Etape = GestionnaireSelection.Etape.PREMIERE_POURSUITE
@export var usage_unique: bool = true

var utilisee: bool = false

@onready var gestionnaire_selection: GestionnaireSelection = get_node_or_null(chemin_gestionnaire_selection) as GestionnaireSelection

func _ready() -> void:
	if not body_entered.is_connected(_quand_corps_entre):
		body_entered.connect(_quand_corps_entre)
	if not area_entered.is_connected(_quand_zone_entre):
		area_entered.connect(_quand_zone_entre)

func _quand_corps_entre(corps: Node2D) -> void:
	declencher_pour(corps)

func _quand_zone_entre(zone: Area2D) -> void:
	var joueur: Player = zone.get_parent() as Player
	if joueur != null:
		declencher_pour(joueur)

func declencher_pour(corps: Node2D) -> bool:
	if utilisee or not corps is Player or gestionnaire_selection == null:
		return false
	if gestionnaire_selection.obtenir_etape_actuelle() != etape_requise:
		return false
	if not gestionnaire_selection.passer_etape(prochaine_etape):
		return false
	if usage_unique:
		utilisee = true
	return true
