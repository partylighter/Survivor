extends Resource
class_name ProjectileVisualProfile

@export_group("Couleurs")
@export var couleur_principale: Color = Color.WHITE
@export var couleur_secondaire: Color = Color(1.0, 1.0, 1.0, 0.85)

@export_group("Forme")
@export_range(0.1, 8.0, 0.01) var echelle_sprite: float = 1.0
@export_range(0.1, 8.0, 0.01) var longueur_visuelle: float = 1.0
@export_range(0.1, 8.0, 0.01) var epaisseur_visuelle: float = 1.0
@export_range(0.0, 8.0, 0.01) var glow_intensite: float = 0.0
@export var rotation_suivre_direction: bool = true

@export_group("Trainee")
@export var trainee_active: bool = true
@export_range(0.1, 8.0, 0.01) var trainee_amount_mult: float = 1.0
@export_range(0.1, 8.0, 0.01) var trainee_scale: float = 1.0

@export_group("Familles")
@export var famille_trail: StringName = &"trail_default"
@export var famille_impact: StringName = &"impact_default"

func remplir_runtime(rt: ProjectileVisualRuntime) -> void:
	if rt == null:
		return
	rt.reset_to_defaults()
	rt.couleur_principale = couleur_principale
	rt.couleur_secondaire = couleur_secondaire
	rt.echelle_sprite = echelle_sprite
	rt.longueur_visuelle = longueur_visuelle
	rt.epaisseur_visuelle = epaisseur_visuelle
	rt.glow_intensite = glow_intensite
	rt.rotation_suivre_direction = rotation_suivre_direction
	rt.trainee_active = trainee_active
	rt.trainee_amount_mult = trainee_amount_mult
	rt.trainee_scale = trainee_scale
	rt.famille_trail = famille_trail
	rt.famille_impact = famille_impact
