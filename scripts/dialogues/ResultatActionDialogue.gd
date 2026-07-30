extends RefCounted
class_name ResultatActionDialogue

enum Statut {
	REUSSIE,
	REFUSEE,
	INCONNUE
}

var statut: Statut = Statut.INCONNUE
var texte_resultat: String = ""
var fermer_ensuite: bool = false

static func creer(nouveau_statut: Statut, nouveau_texte: String, doit_fermer: bool) -> ResultatActionDialogue:
	var resultat: ResultatActionDialogue = ResultatActionDialogue.new()
	resultat.statut = nouveau_statut
	resultat.texte_resultat = nouveau_texte
	resultat.fermer_ensuite = doit_fermer
	return resultat

func est_reussie() -> bool:
	return statut == Statut.REUSSIE
