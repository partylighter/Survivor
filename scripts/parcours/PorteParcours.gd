extends Node2D
class_name PorteParcours

signal ouverte
signal fermee

@export var collision_shape: CollisionShape2D
@export var visuel: CanvasItem
@export var ouverte_au_depart: bool = false
@export var masquer_quand_ouverte: bool = true

var _ouverte: bool = false

func _ready() -> void:
	_ouverte = ouverte_au_depart
	_appliquer_etat()

func ouvrir() -> void:
	if _ouverte:
		return
	_ouverte = true
	_appliquer_etat()
	ouverte.emit()

func fermer() -> void:
	if not _ouverte:
		_appliquer_etat()
		return
	_ouverte = false
	_appliquer_etat()
	fermee.emit()

func est_ouverte() -> bool:
	return _ouverte

func _appliquer_etat() -> void:
	if collision_shape != null:
		collision_shape.set_deferred("disabled", _ouverte)
	if visuel != null and masquer_quand_ouverte:
		visuel.visible = not _ouverte
