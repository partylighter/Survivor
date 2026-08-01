extends Node
class_name GestionnaireEffetsNourriture

var joueur: Player
var soin_regeneration_accumule: float = 0.0

func _ready() -> void:
	joueur = get_parent() as Player
	if joueur == null:
		push_error("GestionnaireEffetsNourriture doit etre un enfant de Player.")

func _process(delta: float) -> void:
	if joueur == null or joueur.stats == null or joueur.sante == null:
		return
	var regeneration: float = maxf(joueur.stats.get_regen_pv_effective(), 0.0)
	var pv_manquants: float = float(joueur.sante.max_pv) - joueur.sante.pv
	if regeneration <= 0.0 or pv_manquants <= 0.0:
		soin_regeneration_accumule = 0.0
		return
	soin_regeneration_accumule += regeneration * delta
	var soin: int = mini(floori(soin_regeneration_accumule), ceili(pv_manquants))
	if soin <= 0:
		return
	soin_regeneration_accumule -= float(soin)
	joueur.sante.heal(soin)

func consommer_nourriture(definition: LootItemEntry) -> bool:
	if joueur == null or definition == null or definition.effet_nourriture == null:
		return false
	var inventaire: GestionnaireInventaire = joueur.inventaire
	var effet: EffetNourriture = definition.effet_nourriture
	if inventaire == null or inventaire.obtenir_quantite(definition.item_id) < 1:
		return false
	if effet.soin > 0 and joueur.sante == null:
		return false
	if effet.restauration_soif > 0.0 and joueur.soif == null:
		return false
	var possede_effet_temporaire: bool = effet.duree > 0.0 and (not is_zero_approx(effet.vitesse_add) or not is_zero_approx(effet.chance_add) or not is_zero_approx(effet.regeneration_add))
	if possede_effet_temporaire and joueur.stats == null:
		return false
	if inventaire.retirer_objet(definition.item_id, 1) != 1:
		return false
	if effet.soin > 0:
		joueur.sante.heal(effet.soin)
	if effet.restauration_soif > 0.0:
		joueur.soif.gagner_soif(effet.restauration_soif)
	if possede_effet_temporaire:
		_appliquer_effet_temporaire(effet)
	return true

func _appliquer_effet_temporaire(effet: EffetNourriture) -> void:
	joueur.stats.ajouter_vitesse_add(effet.vitesse_add)
	joueur.stats.ajouter_chance(effet.chance_add)
	joueur.stats.ajouter_regen_pv_add(effet.regeneration_add)
	var minuteur: SceneTreeTimer = get_tree().create_timer(effet.duree)
	minuteur.timeout.connect(_retirer_effet_temporaire.bind(effet.vitesse_add, effet.chance_add, effet.regeneration_add))

func _retirer_effet_temporaire(vitesse_add: float, chance_add: float, regeneration_add: float) -> void:
	if joueur == null or not is_instance_valid(joueur) or joueur.stats == null:
		return
	joueur.stats.ajouter_vitesse_add(-vitesse_add)
	joueur.stats.ajouter_chance(-chance_add)
	joueur.stats.ajouter_regen_pv_add(-regeneration_add)
