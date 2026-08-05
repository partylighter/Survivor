extends Node
class_name ChampDirectionGrille

const DIRECTIONS_CARDINALES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

@export_range(1, 60, 1) var rayon_flow_field_cellules: int = 20

var _gestionnaire_grille: GestionnaireGrilleCombat
var _cellule_source: Vector2i = Vector2i.ZERO
var _couts: Dictionary = {}

func configurer(gestionnaire: GestionnaireGrilleCombat) -> void:
	_gestionnaire_grille = gestionnaire

func recalculer(cellule_source: Vector2i) -> void:
	if _gestionnaire_grille == null:
		return
	_cellule_source = cellule_source
	_couts.clear()
	_gestionnaire_grille.actualiser_cache_obstacles(cellule_source, rayon_flow_field_cellules)
	var file: Array[Vector2i] = [cellule_source]
	var index: int = 0
	_couts[cellule_source] = 0
	while index < file.size():
		var cellule: Vector2i = file[index]
		index += 1
		var cout: int = int(_couts[cellule])
		for direction in DIRECTIONS_CARDINALES:
			var voisine: Vector2i = cellule + direction
			if _hors_zone(voisine) or _couts.has(voisine):
				continue
			if _gestionnaire_grille.cellule_bloquee_cachee(voisine):
				continue
			_couts[voisine] = cout + 1
			file.append(voisine)

func obtenir_cout(cellule: Vector2i) -> int:
	return int(_couts.get(cellule, -1))

func contient_cellule(cellule: Vector2i) -> bool:
	return _couts.has(cellule)

func obtenir_meilleure_direction(cellule: Vector2i) -> Vector2i:
	var meilleur_cout: int = obtenir_cout(cellule)
	var meilleure_direction: Vector2i = Vector2i.ZERO
	for direction in DIRECTIONS_CARDINALES:
		var cout: int = obtenir_cout(cellule + direction)
		if cout >= 0 and (meilleur_cout < 0 or cout < meilleur_cout):
			meilleur_cout = cout
			meilleure_direction = direction
	return meilleure_direction

func obtenir_cellule_source() -> Vector2i:
	return _cellule_source

func obtenir_rayon() -> int:
	return rayon_flow_field_cellules

func _hors_zone(cellule: Vector2i) -> bool:
	return abs(cellule.x - _cellule_source.x) > rayon_flow_field_cellules or abs(cellule.y - _cellule_source.y) > rayon_flow_field_cellules
