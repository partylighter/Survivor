extends RefCounted
class_name QualiteForge

const QUALITE_MAUVAISE: StringName = &"mauvaise"
const QUALITE_CORRECTE: StringName = &"correcte"
const QUALITE_PARFAITE: StringName = &"parfaite"
const MULTIPLICATEUR_MAUVAISE: float = 0.9
const MULTIPLICATEUR_CORRECTE: float = 1.0
const MULTIPLICATEUR_PARFAITE: float = 1.1

static func obtenir_multiplicateur(qualite: StringName) -> float:
	match qualite:
		QUALITE_MAUVAISE:
			return MULTIPLICATEUR_MAUVAISE
		QUALITE_PARFAITE:
			return MULTIPLICATEUR_PARFAITE
	return MULTIPLICATEUR_CORRECTE

static func obtenir_nom_affiche(qualite: StringName) -> String:
	match qualite:
		QUALITE_MAUVAISE:
			return "Mauvaise"
		QUALITE_PARFAITE:
			return "Parfaite"
	return "Correcte"

static func appliquer_sur_entier(valeur_base: int, qualite: StringName) -> int:
	match qualite:
		QUALITE_MAUVAISE:
			return floori(float(valeur_base) * MULTIPLICATEUR_MAUVAISE)
		QUALITE_PARFAITE:
			return ceili(float(valeur_base) * MULTIPLICATEUR_PARFAITE)
	return valeur_base

static func appliquer_sur_reel(valeur_base: float, qualite: StringName) -> float:
	return valeur_base * obtenir_multiplicateur(qualite)

static func appliquer_vitesse_sur_reel(valeur_base: float, qualite: StringName) -> float:
	var multiplicateur: float = obtenir_multiplicateur(qualite)
	if is_zero_approx(multiplicateur):
		return valeur_base
	return valeur_base / multiplicateur
