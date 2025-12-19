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
	reserve = clampf(stats.reserve_energie_max, 0.0, stats.reserve_energie_max)
	emit_signal("reserve_change", reserve, stats.reserve_energie_max)

func set_reserve_max(nv_max: float, garder_ratio: bool = true) -> void:
	var old_max := maxf(stats.reserve_energie_max, 0.001)
	var old := reserve
	stats.reserve_energie_max = maxf(nv_max, 0.001)

	if garder_ratio:
		var ratio := old / old_max
		reserve = ratio * stats.reserve_energie_max
	else:
		reserve = minf(reserve, stats.reserve_energie_max)

	reserve = clampf(reserve, 0.0, stats.reserve_energie_max)
	_vide_emit = false
	emit_signal("reserve_change", reserve, stats.reserve_energie_max)

func ajouter(amount: float) -> void:
	if amount <= 0.0:
		return
	reserve = clampf(reserve + amount, 0.0, stats.reserve_energie_max)
	_vide_emit = false
	emit_signal("reserve_change", reserve, stats.reserve_energie_max)

func consommer(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if reserve <= 0.0:
		_emit_vide()
		return false

	reserve = maxf(reserve - amount, 0.0)
	emit_signal("reserve_change", reserve, stats.reserve_energie_max)

	if reserve <= 0.0:
		_emit_vide()
		return false

	return true

func tick(dt: float, en_mouvement: bool, en_boost: bool = false) -> void:
	if dt <= 0.0:
		return

	var conso := stats.conso_idle_par_s
	if en_mouvement:
		conso += stats.conso_mouvement_par_s
	if en_boost:
		conso += stats.conso_boost_par_s

	if conso > 0.0:
		consommer(conso * dt)
	elif stats.recharge_par_s > 0.0:
		ajouter(stats.recharge_par_s * dt)

func _emit_vide() -> void:
	if _vide_emit:
		return
	_vide_emit = true
	emit_signal("reserve_vide")
