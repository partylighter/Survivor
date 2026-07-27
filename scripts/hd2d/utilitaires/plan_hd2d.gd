class_name PlanHD2D
extends RefCounted

const ECHELLE_UNITE_PAR_PX: float = 0.00375

static func vers_espace(position_plan: Vector2, hauteur: float = 0.0) -> Vector3:
	return Vector3(position_plan.x * ECHELLE_UNITE_PAR_PX, hauteur, position_plan.y * ECHELLE_UNITE_PAR_PX)

static func vers_plan(position_espace: Vector3) -> Vector2:
	return Vector2(position_espace.x, position_espace.z) / ECHELLE_UNITE_PAR_PX

static func distance_vers_espace(distance_px: float) -> float:
	return distance_px * ECHELLE_UNITE_PAR_PX
