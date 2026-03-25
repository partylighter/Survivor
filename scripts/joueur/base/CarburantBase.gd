extends Node
class_name CarburantBase

signal reserve_change(actuelle: float, max: float)
signal reserve_vide()

@export var stats: StatsBase

var reserve: float = 0.0
var _vide_emit: bool = false

func _ready() -> void:
	if stats == null:
		stats = StatsBase.new()
	stats.reserve_energie_max = maxf(stats.reserve_energie_max, 0.001)
	reserve = clampf(stats.reserve_energie_max, 0.0, stats.reserve_energie_max)
	_vide_emit = false
	emit_signal("reserve_change", reserve, stats.reserve_energie_max)

func get_reserve_max() -> float:
	return maxf(stats.reserve_energie_max, 0.001)

func place_dispo() -> float:
	return maxf(get_reserve_max() - reserve, 0.0)

func est_plein() -> bool:
	return reserve >= get_reserve_max() - 0.0001

func est_vide() -> bool:
	return reserve <= 0.0001

func set_full() -> void:
	reserve = get_reserve_max()
	_vide_emit = false
	emit_signal("reserve_change", reserve, get_reserve_max())

func set_reserve_max(nv_max: float, garder_ratio: bool = true) -> void:
	var old_max := get_reserve_max()
	var old := reserve

	stats.reserve_energie_max = maxf(nv_max, 0.001)
	var new_max := get_reserve_max()

	if garder_ratio:
		var ratio := old / old_max
		reserve = ratio * new_max
	else:
		reserve = minf(reserve, new_max)

	reserve = clampf(reserve, 0.0, new_max)
	_vide_emit = false
	emit_signal("reserve_change", reserve, new_max)

func ajouter(amount: float) -> void:
	if amount <= 0.0:
		return
	var mx := get_reserve_max()
	reserve = clampf(reserve + amount, 0.0, mx)
	_vide_emit = false
	emit_signal("reserve_change", reserve, mx)

func ajouter_reel(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var mx := get_reserve_max()
	var before := reserve
	reserve = clampf(reserve + amount, 0.0, mx)
	var added := reserve - before
	if added > 0.0:
		_vide_emit = false
		emit_signal("reserve_change", reserve, mx)
	return added

func consommer(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if reserve <= 0.0:
		_emit_vide()
		return false

	reserve = maxf(reserve - amount, 0.0)
	emit_signal("reserve_change", reserve, get_reserve_max())

	if reserve <= 0.0:
		_emit_vide()
		return false

	return true

func tick(dt: float, en_mouvement: bool, en_boost: bool = false) -> void:
	if dt <= 0.0:
		return

	var conso := maxf(stats.conso_idle_par_s, 0.0)
	if en_mouvement:
		conso += maxf(stats.conso_mouvement_par_s, 0.0)
	if en_boost:
		conso += maxf(stats.conso_boost_par_s, 0.0)

	if conso > 0.0:
		consommer(conso * dt)
	elif stats.recharge_par_s > 0.0:
		ajouter(stats.recharge_par_s * dt)

func _emit_vide() -> void:
	if _vide_emit:
		return
	_vide_emit = true
	emit_signal("reserve_vide")
