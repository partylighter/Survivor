class_name ZoneDefinition
extends Resource

@export var nom: StringName = &"zone"
@export var x_debut_px: float = 0.0
@export var x_fin_px:   float = 3000.0

@export_group("Spawn")
@export var apparitions_par_sec: float              = 5.0
@export var max_ennemis_zone:    int                = 80
## Liste pratique des scènes autorisées dans cette zone.
## Si renseignée, GestionnaireEnnemis l'utilise directement pour choisir les ennemis.
@export var scenes_ennemis:      Array[PackedScene] = []
## Poids associés à scenes_ennemis.
## Si vide ou de taille incorrecte, le choix se fait uniformément parmi scenes_ennemis.
## Compatibilité: si scenes_ennemis est vide, ce tableau reste interprété
## selon l'ancien système global du gestionnaire.
@export var poids:               PackedFloat32Array = PackedFloat32Array()

@export_group("Boss")
@export var est_zone_boss: bool        = false
@export var scene_boss:    PackedScene = null
## Position X absolue du spawn du boss. Si 0, utilise le centre de la zone.
@export var x_boss_spawn_px: float = 0.0
