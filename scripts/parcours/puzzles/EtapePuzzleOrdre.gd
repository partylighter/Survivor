extends ElementParcours
class_name EtapePuzzleOrdre

@export_range(1, 20, 1) var ordre: int = 1
@export var leurre: bool = false
@export var label_ordre: Label
@export var visuel: CanvasItem

var _puzzle = null

func _ready() -> void:
	if label_ordre != null:
		label_ordre.text = "X" if leurre else str(ordre)
	if visuel != null and leurre:
		visuel.modulate = Color(1.0, 0.35, 0.35, 1.0)

func configurer_puzzle(puzzle) -> void:
	_puzzle = puzzle

func activer(_joueur: CharacterBody2D, _gestionnaire) -> void:
	if _puzzle == null or not _puzzle.has_method("traiter_etape"):
		return
	_puzzle.traiter_etape(self)
