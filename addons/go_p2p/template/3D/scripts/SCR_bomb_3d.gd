extends Area3D

var my_owner = self

signal explode(who,pos)
signal change_player(who)

var ready_for_stick: bool = false
var start_position: Vector3
@onready var explode_timer: Timer = $Explode_Timer

func _ready() -> void:
	start_position = self.global_position
	pass


func _physics_process(delta: float) -> void:
	if not my_owner == self and my_owner != null:
		if not ready_for_stick:
			return
		global_position = my_owner._get_hand_position()
	pass


func _on_body_entered(body: Node3D) -> void:
	if body != my_owner and ready_for_stick :
		change_player.emit(body.name)
	pass

func stick_owner(new_owner):
	ready_for_stick = true
	my_owner = new_owner
	if explode_timer.is_stopped():
		explode_timer.start()
	pass


func _on_explode_timer_timeout() -> void:
	explode.emit(my_owner.name,global_position)
	my_owner = self
	global_position = start_position
	explode_timer.stop()
	
	pass
