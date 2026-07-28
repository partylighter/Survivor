extends RefCounted
class_name CommandeForgeActive

enum Etat {
	EN_ATTENTE,
	EN_COURS,
	TERMINEE,
	REMUNEREE
}

var donnees: DonneesCommandeForge
var etat: Etat = Etat.EN_ATTENTE

func initialiser(nouvelles_donnees: DonneesCommandeForge) -> bool:
	if nouvelles_donnees == null or not nouvelles_donnees.est_valide():
		return false
	donnees = nouvelles_donnees
	etat = Etat.EN_ATTENTE
	return true

func demarrer() -> bool:
	if donnees == null or etat != Etat.EN_ATTENTE:
		return false
	etat = Etat.EN_COURS
	return true

func peut_terminer(inventaire: GestionnaireInventaire) -> bool:
	if donnees == null or etat != Etat.EN_COURS or inventaire == null:
		return false
	return inventaire.obtenir_quantite(donnees.objet_demande.item_id) >= donnees.quantite_demandee

func terminer(inventaire: GestionnaireInventaire) -> bool:
	if not peut_terminer(inventaire):
		return false
	etat = Etat.TERMINEE
	return true

func recuperer_recompense() -> int:
	if donnees == null or etat != Etat.TERMINEE:
		return 0
	etat = Etat.REMUNEREE
	return donnees.prix
