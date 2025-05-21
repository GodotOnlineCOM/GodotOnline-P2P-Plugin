extends CPUParticles3D

func _ready() -> void:
	finished.connect(self._self_destruction)
	
	await get_tree().create_timer(0.1).timeout
	emitting = true


func _self_destruction():
	queue_free()
