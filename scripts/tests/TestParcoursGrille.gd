extends Node2D
class_name TestParcoursGrille

const CELLULE_DEPART: Vector2i = Vector2i(0, 0)
const CELLULE_PUZZLE_FAUSSE: Vector2i = Vector2i(10, 1)
const CELLULES_SOL: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(3, 0),
	Vector2i(4, 0),
	Vector2i(5, 0),
	Vector2i(6, 0),
	Vector2i(7, 0),
	Vector2i(6, -1),
	Vector2i(7, -1),
	Vector2i(8, -1),
	Vector2i(9, -1),
	Vector2i(6, 1),
	Vector2i(7, 1),
	Vector2i(8, 1),
	Vector2i(9, 1),
	Vector2i(9, 0),
	Vector2i(10, 0),
	Vector2i(10, -1),
	Vector2i(11, -1),
	Vector2i(10, 1),
	Vector2i(12, -1),
	Vector2i(12, 0),
	Vector2i(13, 0)
]
const CELLULES_VIDE_REPERE: Array[Vector2i] = [
	Vector2i(2, 0),
	Vector2i(4, 1),
	Vector2i(5, 1),
	Vector2i(11, 0)
]
const SEQUENCE_PUZZLE: Array[Vector2i] = [
	Vector2i(10, 0),
	Vector2i(10, -1),
	Vector2i(11, -1)
]

@export var joueur: CharacterBody2D
@export var deplacement_grille: GestionDeplacementGrilleJoueur
@export var sol_logique: TileMapLayer
@export var porte_puzzle: StaticBody2D
@export var zone_evenement: Area2D
@export var label_etat: Label

var _derniere_cellule_sure: Vector2i = CELLULE_DEPART
var _index_puzzle: int = 0
var _puzzle_termine: bool = false
var _nombre_chutes: int = 0
var _taille_cellule: float = 325.0
var _zone_evenement_declenchee: bool = false

func _ready() -> void:
	if not _configuration_valide():
		return
	_remplir_sol_logique()
	if not deplacement_grille.cellule_atteinte.is_connected(_quand_cellule_atteinte):
		deplacement_grille.cellule_atteinte.connect(_quand_cellule_atteinte)
	if not zone_evenement.body_entered.is_connected(_quand_zone_evenement_entree):
		zone_evenement.body_entered.connect(_quand_zone_evenement_entree)
	_fermer_porte()
	call_deferred(&"_initialiser_joueur")
	queue_redraw()

func _configuration_valide() -> bool:
	var valide: bool = true
	if joueur == null:
		push_error("TestParcoursGrille: joueur absent.")
		valide = false
	if deplacement_grille == null:
		push_error("TestParcoursGrille: GestionDeplacementGrilleJoueur absent.")
		valide = false
	if sol_logique == null:
		push_error("TestParcoursGrille: TileMapLayer de sol absent.")
		valide = false
	if porte_puzzle == null:
		push_error("TestParcoursGrille: porte du puzzle absente.")
		valide = false
	if zone_evenement == null:
		push_error("TestParcoursGrille: zone evenement absente.")
		valide = false
	return valide

func _initialiser_joueur() -> void:
	var gestionnaire_grille := deplacement_grille.obtenir_gestionnaire_grille()
	if gestionnaire_grille != null:
		_taille_cellule = gestionnaire_grille.taille_cellule_px
	joueur.global_position = deplacement_grille.cellule_vers_monde(CELLULE_DEPART)
	deplacement_grille.synchroniser_sur_grille(joueur)
	_derniere_cellule_sure = CELLULE_DEPART
	_actualiser_etat("Départ. Traverse le premier trou avec un dash de 2 cases.")
	queue_redraw()

func _remplir_sol_logique() -> void:
	sol_logique.clear()
	for cellule in CELLULES_SOL:
		sol_logique.set_cell(cellule, 0, Vector2i.ZERO, 0)

func cellule_a_un_sol(cellule: Vector2i) -> bool:
	return sol_logique != null and sol_logique.get_cell_source_id(cellule) >= 0

func _quand_cellule_atteinte(cellule: Vector2i) -> void:
	if not cellule_a_un_sol(cellule):
		_faire_tomber_joueur(cellule)
		return
	_derniere_cellule_sure = cellule
	_traiter_puzzle(cellule)
	queue_redraw()

func _faire_tomber_joueur(cellule: Vector2i) -> void:
	_nombre_chutes += 1
	if not _puzzle_termine:
		_reinitialiser_puzzle()
	joueur.global_position = deplacement_grille.cellule_vers_monde(_derniere_cellule_sure)
	deplacement_grille.synchroniser_sur_grille(joueur)
	_actualiser_etat("Chute depuis %s. Retour à %s." % [str(cellule), str(_derniere_cellule_sure)])
	queue_redraw()

func _traiter_puzzle(cellule: Vector2i) -> void:
	if _puzzle_termine:
		return
	var cellule_concernee: bool = cellule in SEQUENCE_PUZZLE or cellule == CELLULE_PUZZLE_FAUSSE
	if not cellule_concernee:
		return
	var cellule_attendue: Vector2i = SEQUENCE_PUZZLE[_index_puzzle]
	if cellule == cellule_attendue:
		_index_puzzle += 1
		if _index_puzzle >= SEQUENCE_PUZZLE.size():
			_puzzle_termine = true
			_ouvrir_porte()
			_actualiser_etat("Puzzle réussi : 1 → 2 → 3. La porte est ouverte.")
			queue_redraw()
			return
		_actualiser_etat("Puzzle : étape %d/%d validée." % [_index_puzzle, SEQUENCE_PUZZLE.size()])
		queue_redraw()
		return
	_reinitialiser_puzzle()
	_actualiser_etat("Mauvais ordre. Le puzzle repart à 1.")
	queue_redraw()

func _reinitialiser_puzzle() -> void:
	_index_puzzle = 0
	if not _puzzle_termine:
		_fermer_porte()

func _ouvrir_porte() -> void:
	porte_puzzle.collision_layer = 0
	porte_puzzle.visible = false

func _fermer_porte() -> void:
	porte_puzzle.collision_layer = 1
	porte_puzzle.visible = true

func _quand_zone_evenement_entree(body: Node2D) -> void:
	if body != joueur or _zone_evenement_declenchee:
		return
	_zone_evenement_declenchee = true
	_actualiser_etat("Area2D atteinte : exemple d'événement scripté de parcours.")

func _actualiser_etat(message: String) -> void:
	if label_etat == null:
		return
	var progression_puzzle: String = "terminé" if _puzzle_termine else "%d/%d" % [_index_puzzle, SEQUENCE_PUZZLE.size()]
	label_etat.text = "%s\nChutes : %d | Puzzle : %s" % [message, _nombre_chutes, progression_puzzle]

func _draw() -> void:
	for cellule in CELLULES_SOL:
		_dessiner_cellule_sol(cellule)
	for cellule in CELLULES_VIDE_REPERE:
		_dessiner_cellule_vide(cellule)
	var centre_sure: Vector2 = _position_cellule(_derniere_cellule_sure)
	draw_circle(centre_sure, 20.0, Color(0.2, 1.0, 0.45, 1.0))

func _dessiner_cellule_sol(cellule: Vector2i) -> void:
	var couleur := Color(0.10, 0.26, 0.20, 1.0)
	if cellule == SEQUENCE_PUZZLE[0]:
		couleur = Color(0.16, 0.42, 0.78, 1.0)
	elif cellule == SEQUENCE_PUZZLE[1]:
		couleur = Color(0.58, 0.42, 0.12, 1.0)
	elif cellule == SEQUENCE_PUZZLE[2]:
		couleur = Color(0.16, 0.58, 0.34, 1.0)
	elif cellule == CELLULE_PUZZLE_FAUSSE:
		couleur = Color(0.55, 0.12, 0.12, 1.0)
	var demi: float = _taille_cellule * 0.43
	var rect := Rect2(_position_cellule(cellule) - Vector2(demi, demi), Vector2(demi * 2.0, demi * 2.0))
	draw_rect(rect, couleur, true)
	draw_rect(rect, Color(0.45, 0.72, 0.58, 0.75), false, 4.0)

func _dessiner_cellule_vide(cellule: Vector2i) -> void:
	var demi: float = _taille_cellule * 0.43
	var rect := Rect2(_position_cellule(cellule) - Vector2(demi, demi), Vector2(demi * 2.0, demi * 2.0))
	draw_rect(rect, Color(0.22, 0.04, 0.06, 0.35), true)
	draw_rect(rect, Color(0.75, 0.16, 0.20, 0.9), false, 5.0)

func _position_cellule(cellule: Vector2i) -> Vector2:
	if deplacement_grille != null:
		return deplacement_grille.cellule_vers_monde(cellule)
	return Vector2(cellule) * _taille_cellule
