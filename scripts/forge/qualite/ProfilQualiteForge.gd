extends Resource
class_name ProfilQualiteForge

const STAT_DEGATS: StringName = &"degats"
const STAT_RECUL: StringName = &"recul"
const STAT_VITESSE_ATTAQUE: StringName = &"vitesse_attaque"
const STAT_CADENCE: StringName = &"cadence"
const STAT_DISPERSION: StringName = &"dispersion"
const STAT_NOMBRE_PROJECTILES: StringName = &"nombre_projectiles"

@export var utilise_qualite_forge: bool = false
@export var statistiques_influencees: PackedStringArray = PackedStringArray()

func influence_statistique(identifiant_statistique: StringName) -> bool:
	return utilise_qualite_forge and statistiques_influencees.has(identifiant_statistique)
