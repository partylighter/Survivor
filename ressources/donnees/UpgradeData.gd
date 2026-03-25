extends Resource
class_name UpgradeData

enum Target { ARME, PROJECTILE }
enum Mode { SET, ADD, MUL }

@export var id: StringName = &""
@export var cible: Target = Target.ARME
@export var prop: StringName = &""
@export var mode: Mode = Mode.ADD
@export var valeur: float = 0.0
@export var slot: StringName = &"default"
@export_range(1, 999999999999, 1) var max_stacks: int = 1

func is_valid() -> bool:
	return id != &"" and prop != &""

func apply_to(obj: Object, stacks: int = 1) -> bool:
	if obj == null or not is_instance_valid(obj):
		return false
	if prop == &"":
		return false
	if not _has_prop(obj, prop):
		return false

	var cur = obj.get(prop)
	var v := valeur * float(maxi(stacks, 1))

	if typeof(cur) == TYPE_INT or typeof(cur) == TYPE_FLOAT:
		var curf := float(cur)
		var out: float = curf
		match mode:
			Mode.SET:
				out = v
			Mode.ADD:
				out = curf + v
			Mode.MUL:
				out = curf * v
		if typeof(cur) == TYPE_INT:
			obj.set(prop, int(round(out)))
		else:
			obj.set(prop, out)
		return true

	if typeof(cur) == TYPE_BOOL:
		match mode:
			Mode.SET:
				obj.set(prop, bool(v))
				return true
			_:
				return false

	if typeof(cur) == TYPE_VECTOR2:
		var curv: Vector2 = cur
		match mode:
			Mode.SET:
				obj.set(prop, Vector2(v, v))
			Mode.ADD:
				obj.set(prop, curv + Vector2(v, v))
			Mode.MUL:
				obj.set(prop, curv * v)
		return true

	if typeof(cur) == TYPE_VECTOR3:
		var curv3: Vector3 = cur
		match mode:
			Mode.SET:
				obj.set(prop, Vector3(v, v, v))
			Mode.ADD:
				obj.set(prop, curv3 + Vector3(v, v, v))
			Mode.MUL:
				obj.set(prop, curv3 * v)
		return true

	return false

func _has_prop(obj: Object, p: StringName) -> bool:
	var plist := obj.get_property_list()
	for d in plist:
		if StringName(d.get("name", "")) == p:
			return true
	return false
