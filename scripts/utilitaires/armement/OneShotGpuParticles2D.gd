extends GPUParticles2D
class_name OneShotGpuParticles2D

func _ready() -> void:
	one_shot = true
	finished.connect(queue_free)
