extends Node2D
class_name PuzzleOrdre

signal progression_changee(etapes_validees: int, total: int)
signal erreur
signal reinitialise
signal termine

@export var porte: PorteParcours
@export var reinitialiser_sur_erreur: bool = true
@export var fermer_porte_au_depart: bool = true

var _etapes: Array[EtapePuzzleOrdre] = []
var _toutes_etapes: Array[EtapePuzzleOrdre] = []
var _index_attendu: int = 0
var _termine: bool = false
var _configuration_correcte: bool = false

func _ready() -> void:
	_recenser_etapes(self)
	_etapes.sort_custom(Callable(self, "_ordre_avant"))
	_configuration_correcte = _valider_configuration()
	for etape in _toutes_etapes:
		etape.configurer_puzzle(self)
	if porte != null and fermer_porte_au_depart:
		porte.fermer()

func traiter_etape(etape: EtapePuzzleOrdre) -> void:
	if not _configuration_correcte or _termine or etape == null:
		return
	if etape.leurre:
		_traiter_erreur()
		return
	var etape_attendue: EtapePuzzleOrdre = _etapes[_index_attendu]
	if etape != etape_attendue:
		_traiter_erreur()
		return
	_index_attendu += 1
	progression_changee.emit(_index_attendu, _etapes.size())
	if _index_attendu < _etapes.size():
		return
	_termine = true
	if porte != null:
		porte.ouvrir()
	termine.emit()

func reinitialiser() -> void:
	if _termine:
		return
	_index_attendu = 0
	progression_changee.emit(0, _etapes.size())
	reinitialise.emit()

func est_termine() -> bool:
	return _termine

func _traiter_erreur() -> void:
	erreur.emit()
	if reinitialiser_sur_erreur:
		reinitialiser()

func _recenser_etapes(noeud: Node) -> void:
	for enfant in noeud.get_children():
		var etape := enfant as EtapePuzzleOrdre
		if etape != null:
			_toutes_etapes.append(etape)
			if not etape.leurre:
				_etapes.append(etape)
		_recenser_etapes(enfant)

func _valider_configuration() -> bool:
	if _etapes.is_empty():
		push_error("PuzzleOrdre: aucune étape de séquence configurée.")
		return false
	for index in range(_etapes.size()):
		var ordre_attendu: int = index + 1
		if _etapes[index].ordre != ordre_attendu:
			push_error("PuzzleOrdre: les ordres doivent former une séquence unique 1..N. Ordre attendu %d, reçu %d." % [ordre_attendu, _etapes[index].ordre])
			return false
	return true

func _ordre_avant(a: EtapePuzzleOrdre, b: EtapePuzzleOrdre) -> bool:
	return a.ordre < b.ordre
