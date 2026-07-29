extends Control
class_name PointMartelage

@onready var zone_visuelle: ColorRect = $ZoneVisuelle
@onready var numero_ordre: Label = $NumeroOrdre
@onready var nombre_frappes: Label = $NombreFrappes
@onready var progression_duree: ProgressBar = $ProgressionDuree

var identifiant_point: int = -1
var materiau: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	materiau = zone_visuelle.material.duplicate() as ShaderMaterial
	zone_visuelle.material = materiau

func actualiser(donnees: Dictionary, taille_zone: Vector2) -> void:
	identifiant_point = int(donnees.get("identifiant", -1))
	var dimension_zone: float = minf(taille_zone.x, taille_zone.y)
	var rayon: float = float(donnees.get("rayon_exterieur", 0.06)) * dimension_zone
	var diametre: float = rayon * 2.0
	size = Vector2(diametre, diametre)
	position = (donnees.get("position", Vector2(0.5, 0.5)) as Vector2) * taille_zone - size * 0.5
	var duree: float = maxf(float(donnees.get("duree", 1.0)), 0.001)
	var duree_totale: float = duree + maxf(float(donnees.get("duree_grace", 0.0)), 0.0)
	var age: float = float(donnees.get("age", 0.0))
	var progression: float = clampf(age / duree_totale, 0.0, 1.0)
	var moment_parfait: float = maxf(float(donnees.get("moment_parfait", 0.72)), 0.001)
	var progression_rythme: float = clampf((age / duree) / moment_parfait, 0.0, 1.0)
	var ordre: int = int(donnees.get("ordre", 0))
	var frappes_restantes: int = int(donnees.get("frappes_restantes", 1))
	numero_ordre.visible = ordre > 0
	numero_ordre.text = str(ordre)
	nombre_frappes.visible = frappes_restantes > 1
	nombre_frappes.text = "x%d" % frappes_restantes
	progression_duree.value = progression * 100.0
	if materiau != null:
		materiau.set_shader_parameter("ratio_parfait", float(donnees.get("ratio_parfait", 0.35)))
		materiau.set_shader_parameter("ratio_correct", float(donnees.get("ratio_correct", 0.7)))
		materiau.set_shader_parameter("progression_duree", progression)
		materiau.set_shader_parameter("progression_rythme", progression_rythme)
		materiau.set_shader_parameter("point_actif", 1.0 if bool(donnees.get("cliquable", true)) else 0.35)
