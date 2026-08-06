extends Node
class_name EffetSixiemeOeil

@export var intensite_intro: float = 4.0
@export var duree_transition_intro_s: float = 0.25
@export var intensite_active: float = 2.0
@export var intensite_outro: float = 4.0
@export var duree_transition_outro_s: float = 0.25

var _cible: CanvasItem
var _couleur_originale: Color
var _effet_actif: bool = false
var _tween: Tween

func _ready() -> void:
	_cible = get_parent() as CanvasItem
	if _cible == null:
		push_error("EffetSixiemeOeil: le parent doit être un CanvasItem.")
		return
	_couleur_originale = _cible.modulate
	if _cible.is_in_group("esprit_sixieme_oeil"):
		_cible.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		definir_effet_actif(not _effet_actif)

func definir_effet_actif(actif: bool) -> void:
	if _cible == null:
		return
	_effet_actif = actif
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _effet_actif:
		if _cible.is_in_group("esprit_sixieme_oeil"):
			_cible.visible = true
		_appliquer_intensite(intensite_intro)
		_tween = create_tween()
		_tween.tween_property(
			_cible,
			"modulate",
			_obtenir_couleur_intensite(intensite_active),
			duree_transition_intro_s
		)
	else:
		_appliquer_intensite(intensite_outro)
		_tween = create_tween()
		_tween.tween_property(
			_cible,
			"modulate",
			_obtenir_couleur_intensite(1.0),
			duree_transition_outro_s
		)
		if _cible.is_in_group("esprit_sixieme_oeil"):
			_tween.tween_callback(_masquer_cible)

func activer_effet() -> void:
	definir_effet_actif(true)

func desactiver_effet() -> void:
	definir_effet_actif(false)

func _appliquer_intensite(intensite: float) -> void:
	_cible.modulate = _obtenir_couleur_intensite(intensite)

func _obtenir_couleur_intensite(intensite: float) -> Color:
	return Color(
		_couleur_originale.r * intensite,
		_couleur_originale.g * intensite,
		_couleur_originale.b * intensite,
		_couleur_originale.a
	)

func _masquer_cible() -> void:
	if _cible != null and not _effet_actif:
		_cible.visible = false
