extends Node


enum Zone {
	MONDE,
	BASE
}

var zone_actuelle: int = Zone.MONDE
var derniere_position_monde: Vector2 = Vector2.ZERO
