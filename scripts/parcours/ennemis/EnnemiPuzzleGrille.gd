extends OccupantGrille
class_name EnnemiPuzzleGrille

signal deplacement_tour_termine(ennemi: EnnemiPuzzleGrille, reussi: bool)
signal intention_changee(ennemi: EnnemiPuzzleGrille, direction: Vector2i)
signal mort_puzzle(ennemi: EnnemiPuzzleGrille)
signal reinitialise(ennemi: EnnemiPuzzleGrille)

enum ModeActivation {
	CHAQUE_DEPLACEMENT_JOUEUR,
	TOUS_LES_N_DEPLACEMENTS,
	TEMPS_REEL,
	IMMOBILE
}

enum ComportementBlocage {
	ATTENDRE,
	AVANCER_PATTERN
}

enum ComportementVide {
	INTERDIT,
	TOMBE,
	FLOTTE
}

enum CoteImpact {
	AVANT,
	ARRIERE,
	GAUCHE,
	DROITE,
	INDIFFERENCIE
}

@export_group("Identité")
@export var nom_affiche: String = "PUZZLE"
@export_range(0, 1000, 1) var ordre_resolution: int = 0

@export_group("Activation")
@export var mode_activation: ModeActivation = ModeActivation.CHAQUE_DEPLACEMENT_JOUEUR
@export_range(1, 20, 1) var tous_les_n_deplacements: int = 1
@export_range(0.05, 10.0, 0.05) var intervalle_temps_reel_s: float = 1.0
@export_range(0, 50, 1) var distance_activation_joueur_cellules: int = 0

@export_group("Pattern")
@export var pattern: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT]
@export var boucle_pattern: bool = true
@export var comportement_blocage: ComportementBlocage = ComportementBlocage.ATTENDRE
@export var comportement_vide: ComportementVide = ComportementVide.INTERDIT
@export var direction_initiale: Vector2i = Vector2i.RIGHT

@export_group("Interaction joueur")
@export var pousse_joueur: bool = false
@export var inflige_degats: bool = false
@export_range(0, 999999, 1) var degats_joueur: int = 10

@export_group("Vie")
@export var peut_recevoir_degats: bool = true
@export_range(1, 999999, 1) var pv_max: int = 30

@export_group("Vulnérabilité directionnelle")
@export var vulnerable_avant: bool = true
@export var vulnerable_arriere: bool = true
@export var vulnerable_gauche: bool = true
@export var vulnerable_droite: bool = true
@export var vulnerable_indifferencie: bool = true

@export_group("Refs")
@export_node_path("Node") var chemin_sante: NodePath = NodePath("Sante")
@export_node_path("Area2D") var chemin_hurtbox: NodePath = NodePath("HurtBox")
@export_node_path("Node2D") var chemin_orientation_visuelle: NodePath = NodePath("Orientation")
@export_node_path("Label") var chemin_label: NodePath = NodePath("Label")

@onready var sante: Sante = get_node_or_null(chemin_sante) as Sante
@onready var hurtbox: HurtBox = get_node_or_null(chemin_hurtbox) as HurtBox
@onready var orientation_visuelle: Node2D = get_node_or_null(chemin_orientation_visuelle) as Node2D
@onready var label_etat: Label = get_node_or_null(chemin_label) as Label

var direction_regard: Vector2i = Vector2i.RIGHT
var _index_pattern: int = 0
var _pattern_termine: bool = false
var _pattern_valide: bool = true
var _compteur_deplacements_joueur: int = 0
var _temps_reel_s: float = 0.0
var _hors_jeu: bool = false
var _cellule_initiale: Vector2i = Vector2i.ZERO
var _position_initiale: Vector2 = Vector2.ZERO
var _direction_initiale_validee: Vector2i = Vector2i.RIGHT

func _ready() -> void:
	add_to_group("ennemi_puzzle_grille")
	if sante != null:
		sante.max_pv = pv_max
		sante.set_full_pv()
		if not sante.died.is_connected(_quand_mort):
			sante.died.connect(_quand_mort)
		if not sante.damaged.is_connected(_quand_endommage):
			sante.damaged.connect(_quand_endommage)
	if hurtbox != null:
		hurtbox.set_actif(peut_recevoir_degats)
	_valider_pattern()
	_direction_initiale_validee = _normaliser_direction_cardinale(direction_initiale, Vector2i.RIGHT)
	direction_regard = _direction_initiale_validee
	_appliquer_orientation_visuelle()
	_actualiser_label()

func initialiser_parcours(gestionnaire) -> void:
	super(gestionnaire)
	if not _enregistre:
		return
	_cellule_initiale = cellule
	_position_initiale = global_position
	_actualiser_label()

func est_actif_pour_tour() -> bool:
	return _enregistre and not _hors_jeu and _pattern_valide and not _en_deplacement_occupant and not _pattern_termine

func est_mode_temps_reel() -> bool:
	return mode_activation == ModeActivation.TEMPS_REEL

func joueur_dans_zone(cellule_joueur: Vector2i) -> bool:
	if distance_activation_joueur_cellules <= 0:
		return true
	var delta: Vector2i = cellule_joueur - cellule
	return abs(delta.x) + abs(delta.y) <= distance_activation_joueur_cellules

func notifier_deplacement_joueur(cellule_joueur: Vector2i) -> bool:
	if not est_actif_pour_tour() or not joueur_dans_zone(cellule_joueur):
		_compteur_deplacements_joueur = 0
		return false
	match mode_activation:
		ModeActivation.CHAQUE_DEPLACEMENT_JOUEUR:
			return true
		ModeActivation.TOUS_LES_N_DEPLACEMENTS:
			_compteur_deplacements_joueur += 1
			if _compteur_deplacements_joueur >= maxi(tous_les_n_deplacements, 1):
				_compteur_deplacements_joueur = 0
				return true
	return false

func avancer_horloge_temps_reel(dt: float, cellule_joueur: Vector2i) -> bool:
	if mode_activation != ModeActivation.TEMPS_REEL or not est_actif_pour_tour():
		_temps_reel_s = 0.0
		return false
	if not joueur_dans_zone(cellule_joueur):
		_temps_reel_s = 0.0
		return false
	_temps_reel_s += dt
	return _temps_reel_s >= maxf(intervalle_temps_reel_s, 0.05)

func consommer_declenchement_temps_reel() -> void:
	var intervalle: float = maxf(intervalle_temps_reel_s, 0.05)
	_temps_reel_s = maxf(_temps_reel_s - intervalle, 0.0)

func obtenir_direction_intention() -> Vector2i:
	if not est_actif_pour_tour() or pattern.is_empty():
		return Vector2i.ZERO
	var direction: Vector2i = pattern[clampi(_index_pattern, 0, pattern.size() - 1)]
	if direction != Vector2i.ZERO:
		direction_regard = direction
		_appliquer_orientation_visuelle()
	intention_changee.emit(self, direction)
	return direction

func peut_entrer_destination(joueur: CharacterBody2D, destination: Vector2i) -> bool:
	if not est_actif_pour_tour() or gestionnaire_parcours == null:
		return false
	if comportement_vide == ComportementVide.INTERDIT and not gestionnaire_parcours.cellule_est_sure(destination):
		return false
	if gestionnaire_parcours.cellule_est_occupee(destination, self):
		return false
	if gestionnaire_parcours.cellule_est_reservee(destination, self):
		return false
	return destination_physiquement_accessible(joueur, destination)

func demarrer_deplacement_tour(destination: Vector2i) -> bool:
	var direction: Vector2i = destination - cellule
	if abs(direction.x) + abs(direction.y) != 1:
		return false
	direction_regard = direction
	_appliquer_orientation_visuelle()
	return _demarrer_deplacement_occupant(destination, duree_deplacement_s, true)

func avancer_deplacement_tour(dt: float) -> void:
	avancer_deplacement_coordonne(dt)

func resoudre_etape_sans_deplacement(reussie: bool) -> void:
	if reussie or comportement_blocage == ComportementBlocage.AVANCER_PATTERN:
		_avancer_pattern()
	_actualiser_label()

func appliquer_degats_joueur() -> bool:
	if not inflige_degats or degats_joueur <= 0:
		return false
	var hurtbox_joueur := get_tree().get_first_node_in_group("player_hurtbox") as HurtBox
	if hurtbox_joueur == null:
		return false
	return hurtbox_joueur.tek_it(degats_joueur, self)

func accepte_degats_source(source: Node) -> bool:
	if not peut_recevoir_degats or _hors_jeu:
		return false
	return _cote_est_vulnerable(_determiner_cote_impact(source))

func accepte_degats_source_depuis(_source: Node, origine_monde: Vector2) -> bool:
	if not peut_recevoir_degats or _hors_jeu:
		return false
	return _cote_est_vulnerable(_determiner_cote_depuis_position(origine_monde))

func preparer_reinitialisation() -> void:
	if gestionnaire_parcours != null:
		gestionnaire_parcours.liberer_reservations_occupant(self)
		if _enregistre:
			gestionnaire_parcours.retirer_occupant(self, cellule)
	_enregistre = false
	_en_deplacement_occupant = false
	_deplacement_coordonne = false
	set_process(false)
	visible = false

func restaurer_initial() -> bool:
	if gestionnaire_parcours == null or deplacement_grille == null:
		return false
	global_position = _position_initiale
	cellule = _cellule_initiale
	direction_regard = _direction_initiale_validee
	_index_pattern = 0
	_pattern_termine = false
	_compteur_deplacements_joueur = 0
	_temps_reel_s = 0.0
	_hors_jeu = false
	if sante != null:
		sante.max_pv = pv_max
		sante.set_full_pv()
	visible = true
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if hurtbox != null:
		hurtbox.set_actif(peut_recevoir_degats)
	_enregistre = gestionnaire_parcours.enregistrer_occupant(self, cellule)
	if not _enregistre:
		visible = false
		return false
	_appliquer_orientation_visuelle()
	_actualiser_label()
	reinitialise.emit(self)
	return true

func quand_sol_disparait(cellule_sans_sol: Vector2i) -> void:
	if cellule_sans_sol != cellule or _hors_jeu or _en_deplacement_occupant:
		return
	if comportement_vide != ComportementVide.FLOTTE:
		_sortir_par_chute()

func _apres_deplacement_occupant(_ancienne_cellule: Vector2i, _destination: Vector2i, reussi: bool, _destination_occupee: bool) -> void:
	resoudre_etape_sans_deplacement(reussi)
	if reussi and comportement_vide == ComportementVide.TOMBE and gestionnaire_parcours != null and not gestionnaire_parcours.cellule_est_sure(cellule):
		_sortir_par_chute()
	deplacement_tour_termine.emit(self, reussi)

func _valider_pattern() -> void:
	_pattern_valide = true
	for direction in pattern:
		if direction == Vector2i.ZERO:
			continue
		if abs(direction.x) + abs(direction.y) != 1:
			_pattern_valide = false
			push_error("EnnemiPuzzleGrille %s: pattern invalide %s, cardinal ou zéro requis." % [name, str(direction)])
			break

func _avancer_pattern() -> void:
	if pattern.is_empty() or _pattern_termine:
		return
	_index_pattern += 1
	if _index_pattern < pattern.size():
		return
	if boucle_pattern:
		_index_pattern = 0
	else:
		_index_pattern = maxi(pattern.size() - 1, 0)
		_pattern_termine = true

func _normaliser_direction_cardinale(direction: Vector2i, fallback: Vector2i) -> Vector2i:
	if abs(direction.x) + abs(direction.y) == 1:
		return direction
	return fallback

func _determiner_cote_impact(source: Node) -> CoteImpact:
	var source_2d := source as Node2D
	if source_2d == null and source != null:
		source_2d = source.get_parent() as Node2D
	if source_2d == null:
		return CoteImpact.INDIFFERENCIE
	return _determiner_cote_depuis_position(source_2d.global_position)

func _determiner_cote_depuis_position(origine_monde: Vector2) -> CoteImpact:
	var delta: Vector2 = origine_monde - global_position
	if delta.length_squared() <= 0.0001:
		return CoteImpact.INDIFFERENCIE
	var cote_monde: Vector2i
	if absf(delta.x) > absf(delta.y):
		cote_monde = Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
	else:
		cote_monde = Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP
	var avant: Vector2i = _normaliser_direction_cardinale(direction_regard, Vector2i.RIGHT)
	var droite := Vector2i(-avant.y, avant.x)
	if cote_monde == avant:
		return CoteImpact.AVANT
	if cote_monde == -avant:
		return CoteImpact.ARRIERE
	if cote_monde == -droite:
		return CoteImpact.GAUCHE
	if cote_monde == droite:
		return CoteImpact.DROITE
	return CoteImpact.INDIFFERENCIE

func _cote_est_vulnerable(cote: CoteImpact) -> bool:
	match cote:
		CoteImpact.AVANT:
			return vulnerable_avant
		CoteImpact.ARRIERE:
			return vulnerable_arriere
		CoteImpact.GAUCHE:
			return vulnerable_gauche
		CoteImpact.DROITE:
			return vulnerable_droite
	return vulnerable_indifferencie

func _appliquer_orientation_visuelle() -> void:
	if orientation_visuelle == null:
		return
	var direction: Vector2 = Vector2(_normaliser_direction_cardinale(direction_regard, Vector2i.RIGHT))
	orientation_visuelle.rotation = direction.angle()

func _quand_endommage(_montant: int, _source: Node) -> void:
	_actualiser_label()

func _quand_mort() -> void:
	if _hors_jeu:
		return
	if _en_deplacement_occupant:
		terminer_deplacement_immediatement()
	_sortir_hors_jeu()
	mort_puzzle.emit(self)

func _sortir_par_chute() -> void:
	if _hors_jeu:
		return
	_sortir_hors_jeu()
	mort_puzzle.emit(self)

func _sortir_hors_jeu() -> void:
	_hors_jeu = true
	if gestionnaire_parcours != null and _enregistre:
		gestionnaire_parcours.retirer_occupant(self, cellule)
	_enregistre = false
	visible = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if hurtbox != null:
		hurtbox.set_actif(false)
	set_process(false)
	_actualiser_label()

func _actualiser_label() -> void:
	if label_etat == null:
		return
	var texte: String = nom_affiche
	if sante != null and peut_recevoir_degats:
		texte += "\nPV %d/%d" % [roundi(sante.pv), sante.max_pv]
	if _hors_jeu:
		texte += "\nHORS JEU"
	label_etat.text = texte
