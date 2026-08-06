extends Node
class_name EffetMasquageSixiemeOeil

var _cible: CanvasItem
var _effet_actif: bool = false

func _ready() -> void:
	_cible = get_parent() as CanvasItem
	if _cible == null:
		push_error("EffetMasquageSixiemeOeil: le parent doit être un CanvasItem.")
		return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		definir_effet_actif(not _effet_actif)

func definir_effet_actif(actif: bool) -> void:
	if _cible == null:
		return
	_effet_actif = actif
	if _cible.is_in_group("masque_sixieme_oeil"):
		_cible.visible = not _effet_actif

func activer_effet() -> void:
	definir_effet_actif(true)

func desactiver_effet() -> void:
	definir_effet_actif(false)
