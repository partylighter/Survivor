extends Node
class_name EffetSixiemeOeil

@export var intensite_intro: float = 4.0
@export var duree_transition_intro_s: float = 0.25

@export var intensite_active_min: float = 1.8
@export var intensite_active_max: float = 2.5
@export var duree_variation_active_s: float = 0.8

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
	_arreter_tween()
	if _effet_actif:
		_activer_intro()
	else:
		_activer_outro()

func activer_effet() -> void:
	definir_effet_actif(true)

func desactiver_effet() -> void:
	definir_effet_actif(false)

func _activer_intro() -> void:
	if _cible.is_in_group("esprit_sixieme_oeil"):
		_cible.visible = true
	_cible.modulate = _obtenir_couleur_intensite(intensite_intro)
	_tween = create_tween()
	_tween.tween_property(
		_cible,
		"modulate",
		_obtenir_couleur_intensite(intensite_active_min),
		duree_transition_intro_s
	)
	_tween.tween_callback(_demarrer_variation_active)

func _demarrer_variation_active() -> void:
	if not _effet_actif or _cible == null:
		return
	_arreter_tween()
	_tween = create_tween()
	_tween.set_loops()
	_tween.tween_property(
		_cible,
		"modulate",
		_obtenir_couleur_intensite(intensite_active_max),
		duree_variation_active_s
	)
	_tween.tween_property(
		_cible,
		"modulate",
		_obtenir_couleur_intensite(intensite_active_min),
		duree_variation_active_s
	)

func _activer_outro() -> void:
	_cible.modulate = _obtenir_couleur_intensite(intensite_outro)
	_tween = create_tween()
	_tween.tween_property(
		_cible,
		"modulate",
		_obtenir_couleur_intensite(1.0),
		duree_transition_outro_s
	)
	if _cible.is_in_group("esprit_sixieme_oeil"):
		_tween.tween_callback(_masquer_cible)

func _obtenir_couleur_intensite(intensite: float) -> Color:
	return Color(
		_couleur_originale.r * intensite,
		_couleur_originale.g * intensite,
		_couleur_originale.b * intensite,
		_couleur_originale.a
	)

func _arreter_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _masquer_cible() -> void:
	if _cible != null and not _effet_actif:
		_cible.visible = false
