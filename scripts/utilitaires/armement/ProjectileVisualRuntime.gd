extends RefCounted
class_name ProjectileVisualRuntime

var couleur_principale: Color = Color.WHITE
var couleur_secondaire: Color = Color(1.0, 1.0, 1.0, 0.85)

var echelle_sprite: float = 1.0
var longueur_visuelle: float = 1.0
var epaisseur_visuelle: float = 1.0
var glow_intensite: float = 0.0
var rotation_suivre_direction: bool = true

var trainee_active: bool = false
var trainee_amount_mult: float = 1.0
var trainee_scale: float = 1.0

var famille_trail: StringName = &""
var famille_impact: StringName = &""
var trail_scene_resolue: PackedScene = null
var impact_scene_resolue: PackedScene = null

func reset_to_defaults() -> void:
	couleur_principale = Color.WHITE
	couleur_secondaire = Color(1.0, 1.0, 1.0, 0.85)
	echelle_sprite = 1.0
	longueur_visuelle = 1.0
	epaisseur_visuelle = 1.0
	glow_intensite = 0.0
	rotation_suivre_direction = true
	trainee_active = false
	trainee_amount_mult = 1.0
	trainee_scale = 1.0
	famille_trail = &""
	famille_impact = &""
	trail_scene_resolue = null
	impact_scene_resolue = null

func copy_from(other: ProjectileVisualRuntime) -> void:
	if other == null:
		reset_to_defaults()
		return

	couleur_principale = other.couleur_principale
	couleur_secondaire = other.couleur_secondaire
	echelle_sprite = other.echelle_sprite
	longueur_visuelle = other.longueur_visuelle
	epaisseur_visuelle = other.epaisseur_visuelle
	glow_intensite = other.glow_intensite
	rotation_suivre_direction = other.rotation_suivre_direction
	trainee_active = other.trainee_active
	trainee_amount_mult = other.trainee_amount_mult
	trainee_scale = other.trainee_scale
	famille_trail = other.famille_trail
	famille_impact = other.famille_impact
	trail_scene_resolue = other.trail_scene_resolue
	impact_scene_resolue = other.impact_scene_resolue
