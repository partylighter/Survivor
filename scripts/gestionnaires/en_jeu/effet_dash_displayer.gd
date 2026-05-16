extends CanvasLayer
class_name EffetDashDisplayer

@export_node_path("Player") var chemin_joueur: NodePath = NodePath("..")
@export_node_path("ColorRect") var chemin_rect_dash: NodePath = NodePath("RectDash")

@export var intensite_depart: float = 1.0
@export var duree_pulse_s: float = 0.18
@export var aberration_dash_px: float = 8.0
@export_group("Vignette")
@export var vignette_couleur: Color = Color.BLACK
@export_range(0.0, 1.0, 0.01) var vignette_intensite: float = 0.22
@export_range(0.0, 1.0, 0.01) var vignette_opacite: float = 1.0
@export_range(0.0, 1.0, 0.01) var vignette_depart: float = 0.48
@export_range(0.0, 1.5, 0.01) var vignette_fin: float = 1.05
@export var bonus_bandes_dash_px: float = 90.0
@export var duree_resserrement_bandes_s: float = 0.06
@export var duree_desserrement_bandes_s: float = 0.20

const GROUPE_BANDES_NOIRES: StringName = &"bandes_noires_dash"

var joueur: Player = null
var rect_dash: ColorRect = null
var materiau_dash: ShaderMaterial = null
var rect_bandes: ColorRect = null
var materiau_bandes: ShaderMaterial = null
var bande_haut_base_px: float = 0.0
var bande_bas_base_px: float = 0.0
var _ratio_bandes: float = 0.0
var _dash_actif_avant: bool = false
var _interpolation: Tween = null
var _interpolation_bandes: Tween = null

func _ready() -> void:
	joueur = get_node_or_null(chemin_joueur) as Player
	rect_dash = get_node_or_null(chemin_rect_dash) as ColorRect
	if rect_dash != null:
		rect_dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		materiau_dash = rect_dash.material as ShaderMaterial
		_appliquer_intensite(0.0)
		materiau_dash.set_shader_parameter("progression_onde", 0.0)
		materiau_dash.set_shader_parameter("aberration_px", aberration_dash_px)
		_appliquer_parametres_vignette()
	call_deferred("_lier_bandes_noires")

func _process(_delta: float) -> void:
	if joueur == null or not is_instance_valid(joueur):
		joueur = get_node_or_null(chemin_joueur) as Player
	if joueur == null or materiau_dash == null:
		return

	var dash_actif: bool = joueur.dash_t_restant_s > 0.0
	if dash_actif and not _dash_actif_avant:
		lancer_effet_dash(joueur.dash_direction)
		lancer_effet_bandes()

	_dash_actif_avant = dash_actif

func lancer_effet_dash(direction_dash: Vector2) -> void:
	if materiau_dash == null:
		return

	if direction_dash.length_squared() > 0.0001:
		materiau_dash.set_shader_parameter("direction_dash", direction_dash.normalized())

	_appliquer_parametres_vignette()

	if _interpolation != null and _interpolation.is_valid():
		_interpolation.kill()

	_appliquer_intensite(intensite_depart)
	materiau_dash.set_shader_parameter("progression_onde", 0.0)
	_interpolation = create_tween()
	_interpolation.set_parallel(true)
	_interpolation.tween_property(
		materiau_dash,
		"shader_parameter/intensite",
		0.0,
		maxf(duree_pulse_s, 0.01)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_interpolation.tween_property(
		materiau_dash,
		"shader_parameter/progression_onde",
		1.0,
		maxf(duree_pulse_s, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _appliquer_intensite(valeur: float) -> void:
	if materiau_dash == null:
		return
	materiau_dash.set_shader_parameter("intensite", clampf(valeur, 0.0, 1.0))

func _appliquer_parametres_vignette() -> void:
	if materiau_dash == null:
		return
	materiau_dash.set_shader_parameter("vignette_couleur", vignette_couleur)
	materiau_dash.set_shader_parameter("vignette_intensite", vignette_intensite)
	materiau_dash.set_shader_parameter("vignette_opacite", vignette_opacite)
	materiau_dash.set_shader_parameter("vignette_depart", vignette_depart)
	materiau_dash.set_shader_parameter("vignette_fin", vignette_fin)

func lancer_effet_bandes() -> void:
	if materiau_bandes == null:
		_lier_bandes_noires()
	if materiau_bandes == null:
		return

	if _interpolation_bandes != null and _interpolation_bandes.is_valid():
		_interpolation_bandes.kill()

	_interpolation_bandes = create_tween()
	_interpolation_bandes.tween_method(
		_appliquer_ratio_bandes,
		_ratio_bandes,
		1.0,
		maxf(duree_resserrement_bandes_s, 0.01)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_interpolation_bandes.tween_method(
		_appliquer_ratio_bandes,
		1.0,
		0.0,
		maxf(duree_desserrement_bandes_s, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _lier_bandes_noires() -> void:
	if materiau_bandes != null:
		return
	rect_bandes = get_tree().get_first_node_in_group(GROUPE_BANDES_NOIRES) as ColorRect
	if rect_bandes == null:
		return
	materiau_bandes = rect_bandes.material as ShaderMaterial
	if materiau_bandes == null:
		return
	bande_haut_base_px = float(materiau_bandes.get_shader_parameter("bande_haut_px"))
	bande_bas_base_px = float(materiau_bandes.get_shader_parameter("bande_bas_px"))
	_appliquer_ratio_bandes(0.0)

func _appliquer_ratio_bandes(ratio: float) -> void:
	if materiau_bandes == null:
		return
	_ratio_bandes = clampf(ratio, 0.0, 1.0)
	var bonus: float = bonus_bandes_dash_px * _ratio_bandes
	materiau_bandes.set_shader_parameter("bande_haut_px", bande_haut_base_px + bonus)
	materiau_bandes.set_shader_parameter("bande_bas_px", bande_bas_base_px + bonus)
