extends RefCounted
class_name DonneesSelection

var esprits_initiaux: int = 3
var esprits_perdus: int = 0
var degats_recus: float = 0.0
var peur_maximale: float = 0.0
var temps_peur_elevee: float = 0.0
var pieges_declenches: int = 0
var indices_corrects: int = 0
var indices_rates: int = 0
var temps_separe_du_groupe: float = 0.0
var tirs_effectues: int = 0
var tirs_reussis: int = 0
var temps_total_selection: float = 0.0
var fragments_elimines: int = 0

func enregistrer_esprit_perdu() -> void:
	esprits_perdus = mini(esprits_perdus + 1, esprits_initiaux)

func enregistrer_degats(valeur: float) -> void:
	degats_recus += maxf(valeur, 0.0)

func enregistrer_peur(valeur: float) -> void:
	peur_maximale = maxf(peur_maximale, maxf(valeur, 0.0))

func enregistrer_piege_declenche() -> void:
	pieges_declenches += 1

func enregistrer_indice(correct: bool) -> void:
	if correct:
		indices_corrects += 1
	else:
		indices_rates += 1

func enregistrer_tir(reussi: bool) -> void:
	tirs_effectues += 1
	if reussi:
		tirs_reussis += 1

func ajouter_temps_separation(delta: float) -> void:
	temps_separe_du_groupe += maxf(delta, 0.0)

func ajouter_temps_peur_elevee(delta: float) -> void:
	temps_peur_elevee += maxf(delta, 0.0)

func ajouter_temps_selection(delta: float) -> void:
	temps_total_selection += maxf(delta, 0.0)

func enregistrer_fragment_elimine() -> void:
	fragments_elimines += 1
