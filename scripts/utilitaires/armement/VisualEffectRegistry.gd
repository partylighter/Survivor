extends RefCounted
class_name VisualEffectRegistry

static var _trail_map: Dictionary = {}
static var _impact_map: Dictionary = {
	&"impact_default": preload("res://scenes/vfx/projectiles/impact_default.tscn"),
}

static func register_trail(famille: StringName, scene: PackedScene) -> void:
	if famille == &"":
		return
	_trail_map[famille] = scene

static func register_impact(famille: StringName, scene: PackedScene) -> void:
	if famille == &"":
		return
	_impact_map[famille] = scene

static func resoudre_trail(famille: StringName) -> PackedScene:
	if famille == &"":
		return null
	return _trail_map.get(famille, null) as PackedScene

static func resoudre_impact(famille: StringName) -> PackedScene:
	if famille == &"":
		return null
	return _impact_map.get(famille, null) as PackedScene
