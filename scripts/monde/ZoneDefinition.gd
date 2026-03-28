class_name ZoneDefinition
extends Resource

@export var nom: StringName = &"zone"
@export var x_debut_px: float = 0.0
@export var x_fin_px:   float = 3000.0

@export_group("Spawn")
@export var apparitions_par_sec: float              = 5.0
@export var max_ennemis_zone:    int                = 80
## Un float par entrée de scenes_ennemis dans GestionnaireEnnemis, même ordre.
## Ex : [0.6, 0.4, 0.0, 0.0, 0.0] → 60 % type 0, 40 % type 1.
@export var poids:               PackedFloat32Array = PackedFloat32Array()

@export_group("Boss")
@export var est_zone_boss: bool        = false
@export var scene_boss:    PackedScene = null
