extends RefCounted
class_name ProjectileVisualDelta

var override_couleur_principale_active: bool = false
var override_couleur_principale: Color = Color.WHITE

var override_couleur_secondaire_active: bool = false
var override_couleur_secondaire: Color = Color.WHITE

var echelle_add: float = 0.0
var echelle_mult: float = 1.0

var longueur_add: float = 0.0
var longueur_mult: float = 1.0

var epaisseur_add: float = 0.0
var epaisseur_mult: float = 1.0

var glow_add: float = 0.0
var trainee_amount_mult: float = 1.0
var trainee_scale_mult: float = 1.0

var override_famille_trail_active: bool = false
var override_famille_trail: StringName = &""

var override_famille_impact_active: bool = false
var override_famille_impact: StringName = &""

func reset_to_defaults() -> void:
	override_couleur_principale_active = false
	override_couleur_principale = Color.WHITE
	override_couleur_secondaire_active = false
	override_couleur_secondaire = Color.WHITE
	echelle_add = 0.0
	echelle_mult = 1.0
	longueur_add = 0.0
	longueur_mult = 1.0
	epaisseur_add = 0.0
	epaisseur_mult = 1.0
	glow_add = 0.0
	trainee_amount_mult = 1.0
	trainee_scale_mult = 1.0
	override_famille_trail_active = false
	override_famille_trail = &""
	override_famille_impact_active = false
	override_famille_impact = &""
