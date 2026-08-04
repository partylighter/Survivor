extends Node
class_name GestionnaireSelection

signal selection_demarre
signal etape_changee(etape: Etape)
signal selection_terminee

enum Etape {
	PRESENTATION,
	PREMIERE_POURSUITE,
	TRAQUE,
	DEUXIEME_CONFRONTATION,
	PEUR,
	DERNIERE_POURSUITE,
	BOSS,
	EVALUATION,
	TERMINEE
}

@export var demarrage_automatique: bool = true

var etape_actuelle: Etape = Etape.PRESENTATION
var donnees_selection: DonneesSelection
var selection_active: bool = false

func _ready() -> void:
	if demarrage_automatique:
		call_deferred(&"demarrer_selection")

func _process(delta: float) -> void:
	if selection_active and donnees_selection != null:
		donnees_selection.ajouter_temps_selection(delta)

func demarrer_selection() -> bool:
	if selection_active:
		return false
	donnees_selection = DonneesSelection.new()
	etape_actuelle = Etape.PRESENTATION
	selection_active = true
	selection_demarre.emit()
	etape_changee.emit(etape_actuelle)
	print("[Selection] Etape -> ", Etape.keys()[etape_actuelle])
	return true

func passer_etape(nouvelle_etape: Etape) -> bool:
	if not selection_active or nouvelle_etape == etape_actuelle:
		return false
	etape_actuelle = nouvelle_etape
	etape_changee.emit(etape_actuelle)
	print("[Selection] Etape -> ", Etape.keys()[etape_actuelle])
	if etape_actuelle == Etape.TERMINEE:
		selection_active = false
		selection_terminee.emit()
	return true

func terminer_etape() -> bool:
	if not selection_active or etape_actuelle == Etape.TERMINEE:
		return false
	return passer_etape(obtenir_etape_suivante(etape_actuelle))

func obtenir_etape_suivante(etape: Etape) -> Etape:
	match etape:
		Etape.PRESENTATION:
			return Etape.PREMIERE_POURSUITE
		Etape.PREMIERE_POURSUITE:
			return Etape.TRAQUE
		Etape.TRAQUE:
			return Etape.DEUXIEME_CONFRONTATION
		Etape.DEUXIEME_CONFRONTATION:
			return Etape.PEUR
		Etape.PEUR:
			return Etape.DERNIERE_POURSUITE
		Etape.DERNIERE_POURSUITE:
			return Etape.BOSS
		Etape.BOSS:
			return Etape.EVALUATION
		Etape.EVALUATION:
			return Etape.TERMINEE
	return Etape.TERMINEE

func obtenir_etape_actuelle() -> Etape:
	return etape_actuelle

func est_selection_active() -> bool:
	return selection_active

func enregistrer_peur(valeur: float) -> void:
	if donnees_selection != null:
		donnees_selection.enregistrer_peur(valeur)
