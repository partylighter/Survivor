extends Node
class_name GestionnaireGrilleCombat

signal reservation_changee

const OFFSETS_SLOTS_DEFAUT: Array[Vector2] = [Vector2(-22.0, -22.0), Vector2(22.0, -22.0), Vector2(-22.0, 22.0), Vector2(22.0, 22.0)]

@export_group("Grille commune")
@export var taille_cellule_px: float = 100.0
@export var origine_grille: Vector2 = Vector2.ZERO
@export var offsets_slots: Array[Vector2] = OFFSETS_SLOTS_DEFAUT.duplicate():
	set(nouveaux_offsets):
		offsets_slots = OFFSETS_SLOTS_DEFAUT.duplicate() if nouveaux_offsets.is_empty() else nouveaux_offsets.duplicate()

@export_group("Obstacles")
@export_flags_2d_physics var masque_obstacles: int = 1
@export var rayon_test_obstacle_px: float = 46.34

@export_group("Refs")
@export_node_path("ChampDirectionGrille") var chemin_champ_direction: NodePath = NodePath("ChampDirectionGrille")

var _champ_direction: ChampDirectionGrille
var _occupations: Dictionary = {}
var _reservations: Dictionary = {}
var _occupation_par_ennemi: Dictionary = {}
var _reservation_par_ennemi: Dictionary = {}
var _cellules_bloquees: Dictionary = {}
var _slots_bloques: Dictionary = {}
var _cellules_scanees: Dictionary = {}
var _forme_obstacle := CircleShape2D.new()
var _forme_detection_cellule := CircleShape2D.new()
var _deplacement_joueur: GestionDeplacementGrilleJoueur

func _ready() -> void:
	_restaurer_offsets_slots_si_vides()
	add_to_group("grille_combat")
	_champ_direction = get_node_or_null(chemin_champ_direction) as ChampDirectionGrille
	if _champ_direction != null:
		_champ_direction.configurer(self)
	_forme_obstacle.radius = maxf(rayon_test_obstacle_px, 1.0)
	_actualiser_rayon_detection_cellule()
	call_deferred("_connecter_joueur")

func _process(_dt: float) -> void:
	if _deplacement_joueur == null or not is_instance_valid(_deplacement_joueur):
		_connecter_joueur()

func cellule_vers_monde(cellule: Vector2i) -> Vector2:
	return origine_grille + Vector2(cellule) * maxf(taille_cellule_px, 1.0)

func monde_vers_cellule(position_monde: Vector2) -> Vector2i:
	var coordonnee: Vector2 = (position_monde - origine_grille) / maxf(taille_cellule_px, 1.0)
	return Vector2i(roundi(coordonnee.x), roundi(coordonnee.y))

func position_slot(cellule: Vector2i, index_slot: int) -> Vector2:
	if index_slot < 0 or index_slot >= offsets_slots.size():
		return cellule_vers_monde(cellule)
	return cellule_vers_monde(cellule) + offsets_slots[index_slot]

func obtenir_slots_libres(cellule: Vector2i) -> Array[int]:
	_nettoyer_entrees_invalides_cellule(cellule)
	var resultat: Array[int] = []
	for index_slot in range(offsets_slots.size()):
		var cle := _cle_slot(cellule, index_slot)
		if not _slots_bloques.has(cle) and not _occupations.has(cle) and not _reservations.has(cle):
			resultat.append(index_slot)
	return resultat

func reserver_slot(cellule: Vector2i, index_slot: int, ennemi: Enemy) -> bool:
	if ennemi == null or index_slot < 0 or index_slot >= offsets_slots.size():
		return false
	assurer_cellule_cachee(cellule)
	var cle := _cle_slot(cellule, index_slot)
	_nettoyer_cle_invalide(cle)
	if _slots_bloques.has(cle) or _occupations.has(cle) or _reservations.has(cle):
		return false
	_liberer_reservation_ennemi(ennemi)
	_reservations[cle] = ennemi
	_reservation_par_ennemi[ennemi] = cle
	reservation_changee.emit()
	return true

func confirmer_occupation(cellule: Vector2i, index_slot: int, ennemi: Enemy) -> void:
	if ennemi == null:
		return
	var cle := _cle_slot(cellule, index_slot)
	var reservation: Variant = _reservations.get(cle)
	if reservation != ennemi:
		return
	_liberer_occupation_ennemi(ennemi)
	_reservations.erase(cle)
	_reservation_par_ennemi.erase(ennemi)
	_occupations[cle] = ennemi
	_occupation_par_ennemi[ennemi] = cle
	reservation_changee.emit()

func enregistrer_occupation(cellule: Vector2i, index_slot: int, ennemi: Enemy) -> bool:
	if not reserver_slot(cellule, index_slot, ennemi):
		return false
	confirmer_occupation(cellule, index_slot, ennemi)
	return true

func liberer_slot(cellule: Vector2i, index_slot: int, ennemi: Enemy) -> void:
	var cle := _cle_slot(cellule, index_slot)
	if _occupations.get(cle) == ennemi:
		_occupations.erase(cle)
		_occupation_par_ennemi.erase(ennemi)
	if _reservations.get(cle) == ennemi:
		_reservations.erase(cle)
		_reservation_par_ennemi.erase(ennemi)
	reservation_changee.emit()

func liberer_toutes_reservations_ennemi(ennemi: Enemy) -> void:
	if ennemi == null:
		return
	_liberer_reservation_ennemi(ennemi)
	_liberer_occupation_ennemi(ennemi)
	reservation_changee.emit()

func obtenir_nombre_slots_utilises(cellule: Vector2i) -> int:
	_nettoyer_entrees_invalides_cellule(cellule)
	var total: int = 0
	for index_slot in range(offsets_slots.size()):
		var cle := _cle_slot(cellule, index_slot)
		if _occupations.has(cle) or _reservations.has(cle):
			total += 1
	return total

func obtenir_cout_congestion(cellule: Vector2i) -> int:
	match obtenir_nombre_slots_utilises(cellule):
		0: return 0
		1: return 1
		2: return 3
		3: return 6
		_: return 1000000

func obtenir_occupant(cellule: Vector2i, index_slot: int) -> Enemy:
	var cle := _cle_slot(cellule, index_slot)
	_nettoyer_cle_invalide(cle)
	return _occupations.get(cle) as Enemy

func obtenir_reservataire(cellule: Vector2i, index_slot: int) -> Enemy:
	var cle := _cle_slot(cellule, index_slot)
	_nettoyer_cle_invalide(cle)
	return _reservations.get(cle) as Enemy

func actualiser_cache_obstacles(centre: Vector2i, rayon: int) -> void:
	_forme_obstacle.radius = maxf(rayon_test_obstacle_px, 1.0)
	_actualiser_rayon_detection_cellule()
	for y in range(-rayon, rayon + 1):
		for x in range(-rayon, rayon + 1):
			var cellule := centre + Vector2i(x, y)
			assurer_cellule_cachee(cellule)

func assurer_cellule_cachee(cellule: Vector2i) -> void:
	if _cellules_scanees.has(cellule):
		return
	_cellules_scanees[cellule] = true
	if not _position_touche_obstacle(cellule_vers_monde(cellule), _forme_detection_cellule):
		return
	var nombre_slots_bloques: int = 0
	for index_slot in range(offsets_slots.size()):
		if _position_touche_obstacle(position_slot(cellule, index_slot), _forme_obstacle):
			_slots_bloques[_cle_slot(cellule, index_slot)] = true
			nombre_slots_bloques += 1
	if offsets_slots.is_empty() or nombre_slots_bloques >= offsets_slots.size():
		_cellules_bloquees[cellule] = true

func cellule_bloquee_cachee(cellule: Vector2i) -> bool:
	return _cellules_bloquees.has(cellule)

func cellule_bloquee_ou_scanner(cellule: Vector2i) -> bool:
	assurer_cellule_cachee(cellule)
	return cellule_bloquee_cachee(cellule)

func slot_bloque_cache(cellule: Vector2i, index_slot: int) -> bool:
	return _slots_bloques.has(_cle_slot(cellule, index_slot))

func invalider_cellule(cellule: Vector2i) -> void:
	_cellules_scanees.erase(cellule)
	_cellules_bloquees.erase(cellule)
	for index_slot in range(offsets_slots.size()):
		_slots_bloques.erase(_cle_slot(cellule, index_slot))

func invalider_cache_obstacles() -> void:
	_cellules_scanees.clear()
	_cellules_bloquees.clear()
	_slots_bloques.clear()

func recalculer_champ(cellule_joueur: Vector2i) -> void:
	if _champ_direction != null:
		_champ_direction.recalculer(cellule_joueur)

func obtenir_cout_champ(cellule: Vector2i) -> int:
	return _champ_direction.obtenir_cout(cellule) if _champ_direction != null else -1

func champ_contient(cellule: Vector2i) -> bool:
	return _champ_direction != null and _champ_direction.contient_cellule(cellule)

func obtenir_direction_champ(cellule: Vector2i) -> Vector2i:
	return _champ_direction.obtenir_meilleure_direction(cellule) if _champ_direction != null else Vector2i.ZERO

func obtenir_cellule_joueur() -> Vector2i:
	return _champ_direction.obtenir_cellule_source() if _champ_direction != null else Vector2i.ZERO

func obtenir_rayon_champ() -> int:
	return _champ_direction.obtenir_rayon() if _champ_direction != null else 0

func _connecter_joueur() -> void:
	var nouveau_deplacement := get_tree().get_first_node_in_group("deplacement_grille_joueur") as GestionDeplacementGrilleJoueur
	if nouveau_deplacement == null:
		return
	if _deplacement_joueur == nouveau_deplacement:
		return
	_deplacement_joueur = nouveau_deplacement
	if not _deplacement_joueur.cellule_atteinte.is_connected(_sur_cellule_joueur_atteinte):
		_deplacement_joueur.cellule_atteinte.connect(_sur_cellule_joueur_atteinte)
	recalculer_champ(_deplacement_joueur.obtenir_cellule_actuelle())

func _sur_cellule_joueur_atteinte(cellule: Vector2i) -> void:
	recalculer_champ(cellule)

func _cle_slot(cellule: Vector2i, index_slot: int) -> Vector3i:
	return Vector3i(cellule.x, cellule.y, index_slot)

func _actualiser_rayon_detection_cellule() -> void:
	_restaurer_offsets_slots_si_vides()
	var decalage_max: float = 0.0
	for offset in offsets_slots:
		decalage_max = maxf(decalage_max, offset.length())
	_forme_detection_cellule.radius = maxf(rayon_test_obstacle_px + decalage_max, 1.0)

func _restaurer_offsets_slots_si_vides() -> void:
	if offsets_slots.is_empty():
		offsets_slots = OFFSETS_SLOTS_DEFAUT.duplicate()

func _position_touche_obstacle(position_monde: Vector2, forme: Shape2D) -> bool:
	var parametres := PhysicsShapeQueryParameters2D.new()
	parametres.shape = forme
	parametres.transform = Transform2D(0.0, position_monde)
	parametres.collision_mask = masque_obstacles
	parametres.collide_with_bodies = true
	parametres.collide_with_areas = false
	var resultats: Array[Dictionary] = get_viewport().world_2d.direct_space_state.intersect_shape(parametres, 32)
	for resultat in resultats:
		var collisionneur: Object = resultat.get("collider") as Object
		if collisionneur is Player or collisionneur is Enemy:
			continue
		return true
	return false

func _nettoyer_entrees_invalides_cellule(cellule: Vector2i) -> void:
	for index_slot in range(offsets_slots.size()):
		_nettoyer_cle_invalide(_cle_slot(cellule, index_slot))

func _nettoyer_cle_invalide(cle: Vector3i) -> void:
	if _occupations.has(cle) and not is_instance_valid(_occupations[cle]):
		_occupations.erase(cle)
	if _reservations.has(cle) and not is_instance_valid(_reservations[cle]):
		_reservations.erase(cle)

func _liberer_reservation_ennemi(ennemi: Enemy) -> void:
	if not _reservation_par_ennemi.has(ennemi):
		return
	var cle: Vector3i = _reservation_par_ennemi[ennemi]
	if _reservations.get(cle) == ennemi:
		_reservations.erase(cle)
	_reservation_par_ennemi.erase(ennemi)

func _liberer_occupation_ennemi(ennemi: Enemy) -> void:
	if not _occupation_par_ennemi.has(ennemi):
		return
	var cle: Vector3i = _occupation_par_ennemi[ennemi]
	if _occupations.get(cle) == ennemi:
		_occupations.erase(cle)
	_occupation_par_ennemi.erase(ennemi)
