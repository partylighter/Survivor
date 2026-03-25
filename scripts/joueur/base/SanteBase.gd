extends Node
class_name SanteBase

signal sante_change(actuelle: int, max: int)
signal detruit()
signal soigne(amount: int)
signal degats(amount: int)

@export var stats: StatsBase

var sante: int = 1
var _detruite: bool = false

func _ready() -> void:
	if stats == null:
		stats = StatsBase.new()
	sante = max(stats.sante_max, 1)
	emit_signal("sante_change", sante, stats.sante_max)

func est_detruite() -> bool:
	return _detruite

func set_sante_max(nv_max: int, garder_ratio: bool = true) -> void:
	var old_max = max(stats.sante_max, 1)
	var old := sante
	stats.sante_max = max(nv_max, 1)

	if garder_ratio:
		var ratio := float(old) / float(old_max)
		sante = int(round(ratio * float(stats.sante_max)))
	else:
		sante = min(sante, stats.sante_max)

	sante = clampi(sante, 0, stats.sante_max)
	emit_signal("sante_change", sante, stats.sante_max)

func appliquer_degats(amount: int) -> void:
	if _detruite:
		return
	var dmg := maxi(amount, 0)
	if dmg <= 0:
		return

	sante = maxi(sante - dmg, 0)
	emit_signal("degats", dmg)
	emit_signal("sante_change", sante, stats.sante_max)

	if sante <= 0 and not _detruite:
		_detruite = true
		emit_signal("detruit")

func soigner(amount: int) -> void:
	if _detruite:
		return
	var heal := maxi(amount, 0)
	if heal <= 0:
		return
	sante = mini(sante + heal, stats.sante_max)
	emit_signal("soigne", heal)
	emit_signal("sante_change", sante, stats.sante_max)
