extends ElementParcours
class_name PlateformeFragile

@export_group("Disparition")
@export_range(0.05, 10.0, 0.05) var delai_disparition_s: float = 0.8
@export var reapparition_active: bool = true
@export_range(0.05, 20.0, 0.05) var delai_reapparition_s: float = 2.0

var _gestionnaire: GestionnaireParcoursGrille
var _declenchee: bool = false
var _active: bool = true
var _temps_restant_s: float = 0.0
var _attente_reapparition: bool = false

func initialiser_parcours(gestionnaire: GestionnaireParcoursGrille) -> void:
	_gestionnaire = gestionnaire
	if _gestionnaire == null:
		return
	_gestionnaire.enregistrer_sol_dynamique(self, cellule)
	set_process(false)

func activer(_joueur: CharacterBody2D, _gestionnaire_parcours) -> void:
	if not _active or _declenchee:
		return
	_declenchee = true
	_temps_restant_s = maxf(delai_disparition_s, 0.05)
	set_process(true)

func _process(dt: float) -> void:
	_temps_restant_s = maxf(_temps_restant_s - dt, 0.0)
	if _temps_restant_s > 0.0:
		return
	if _attente_reapparition:
		_reapparaitre()
		return
	_disparaitre()

func _disparaitre() -> void:
	_active = false
	visible = false
	if _gestionnaire != null and is_instance_valid(_gestionnaire):
		_gestionnaire.retirer_sol_dynamique(self, cellule)
	if reapparition_active:
		_attente_reapparition = true
		_temps_restant_s = maxf(delai_reapparition_s, 0.05)
		return
	set_process(false)

func _reapparaitre() -> void:
	_active = true
	_declenchee = false
	_attente_reapparition = false
	visible = true
	if _gestionnaire != null and is_instance_valid(_gestionnaire):
		_gestionnaire.enregistrer_sol_dynamique(self, cellule)
	set_process(false)

func _exit_tree() -> void:
	if _gestionnaire != null and is_instance_valid(_gestionnaire):
		_gestionnaire.retirer_sol_dynamique(self, cellule)
