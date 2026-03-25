extends Node
class_name UpgradeRegistry

@export var debug_registry: bool = false
@export var upgrades: Array[UpgradeData] = []

var _map: Dictionary = {}

func _ready() -> void:
	add_to_group("upgrade_registry")
	rebuild()

func rebuild() -> void:
	_map.clear()
	for u in upgrades:
		if u == null:
			continue
		if not u.is_valid():
			if debug_registry:
				print("[UpgradeRegistry] invalide: ", u)
			continue
		_map[u.id] = u
	if debug_registry:
		print("[UpgradeRegistry] loaded=", _map.size())

func has_upgrade(id_item: StringName) -> bool:
	return _map.has(id_item)

func get_upgrade(id_item: StringName) -> UpgradeData:
	if _map.has(id_item):
		return _map[id_item] as UpgradeData
	return null

func register_upgrade(u: UpgradeData) -> void:
	if u == null or not u.is_valid():
		return
	_map[u.id] = u
	if debug_registry:
		print("[UpgradeRegistry] register ", String(u.id))

func unregister_upgrade(id_item: StringName) -> void:
	if _map.has(id_item):
		_map.erase(id_item)
		if debug_registry:
			print("[UpgradeRegistry] unregister ", String(id_item))

func rebuild_now() -> void:
	rebuild()

func get_all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _map.keys():
		out.append(k as StringName)
	return out
