extends Node2D
class_name ProjectileHub

func add_projectile(p: Projectile) -> void:
	add_child(p)

func clear_all() -> void:
	for c in get_children():
		if c is Projectile:
			(c as Projectile).desactiver()
		c.queue_free()
