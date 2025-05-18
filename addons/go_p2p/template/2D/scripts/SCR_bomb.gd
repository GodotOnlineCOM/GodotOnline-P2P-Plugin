extends CharacterBody2D
@onready var timer: Timer = $Timer
@export var curve: Curve
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var particle: CPUParticles2D = $Particle

var exploded: bool = false
var random_time: int
func _ready() -> void:
	timer.start(random_time)
	animated_sprite_2d.play("idle")



func _physics_process(delta: float) -> void:
	if not timer.is_stopped():
		var progress = 1.0 - (timer.time_left / timer.wait_time)
		var curve_value = curve.sample(progress)
		animated_sprite_2d.self_modulate = Color.WHITE.lerp(Color.RED, curve_value)
		
		if timer.time_left <= 3.0:
			var flash_intensity = 1.0 - (timer.time_left / 3.0) # 0-1 arası
			var flash_value = sin(Time.get_ticks_msec() * 0.01 * (1.0 + flash_intensity * 2.0)) * 0.2 * flash_intensity
			animated_sprite_2d.self_modulate.v = 1.0 + flash_value
	
	if exploded and not animated_sprite_2d.is_playing() and not particle.emitting:
		queue_free()

func _on_timer_timeout() -> void:
	timer.stop()
	animated_sprite_2d.play("explode")
	particle.emitting = true
