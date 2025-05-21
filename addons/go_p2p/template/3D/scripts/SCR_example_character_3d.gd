extends CharacterBody3D

## Movement settings
@export var move_speed : float = 5.0
@export var sprint_speed : float = 8.0
@export var jump_force : float = 4.5
@export var mouse_sensitivity : float = 0.002

## Interpolation settings
@export var interpolation_speed : float = 8.0
@export var max_history_size : int = 5
@export var extrapolation_factor : float = 0.6
@export var use_velocity_interpolation : bool = true

## Camera
@onready var camera_pivot : Node3D = $CameraPivot
@onready var camera : Camera3D = $CameraPivot/Camera3D

@onready var simple_character: MeshInstance3D = $stck1/Armature/Skeleton3D/Simple_Character

## Animations
@export var animation_player : AnimationPlayer
@export var animation_tree : AnimationTree

@export var movement_curve : Curve
@export var movement_curve2 : Curve
var acceleration_progress : float = 0.0
@export var acceleration_time := 0.5
var deceleration_progress : float = 0.0
@export var deceleration_time := 0.3


@onready var hand: Marker3D = $hand

## Network & Interpolation variables.
var is_local_player : bool = false
var current_speed : float = move_speed
var interpolation : AdvancedInterpolation = AdvancedInterpolation.new()
var last_sync_time : int = 0
var network_latency : float = 0.0
var is_game_started = true
var is_eliminated = false
func _ready():
	# Interpolation settings
	interpolation.interpolation_speed = interpolation_speed
	interpolation.max_history_size = max_history_size
	interpolation.extrapolation_factor = extrapolation_factor
	interpolation.use_velocity = use_velocity_interpolation

func _enter_tree():
	# Multiplayer authority settings
	set_multiplayer_authority(str(name).to_int())

func _game_started():
	is_game_started = true


func _eliminated(pos):
	is_eliminated = true
	global_position = pos

func _input(event):
	if !is_local_player: return

func change_color(ch_color : Color):
	var newMat = StandardMaterial3D.new()
	newMat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	newMat.albedo_color = ch_color
	simple_character.material_override = newMat
	
	if is_multiplayer_authority():
		is_local_player = true
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pass

func _physics_process(delta):
	if is_multiplayer_authority():
		# Movement process for local player
		_process_local_movement(delta)
		update_animations()
		
	else:
		# interpolation for other players
		_process_remote_movement(delta)

func _process_local_movement(delta):
	if not is_game_started:
		return
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	
	var camera_forward = -camera.global_transform.basis.z
	var camera_right = camera.global_transform.basis.x
	var direction = (camera_forward * input_dir.y + camera_right * input_dir.x).normalized()
	direction.y = 0 
	
	current_speed = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	if direction.length() > 0.1:
		look_at(global_transform.origin + direction, Vector3.UP)
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	
	if !is_on_floor() and not is_eliminated:
		velocity.y -= 9.8 * delta
	else:
		if Input.is_action_just_pressed("ui_accept") and not is_eliminated:
			velocity.y = jump_force
	if velocity.length() > 1.0:
		acceleration_progress = min(acceleration_progress + delta / acceleration_time , 1.0)
		deceleration_progress = 0.0
	else:
		deceleration_progress = min(deceleration_progress + delta / deceleration_time , 1.0)
		acceleration_progress = 0.0
	
	move_and_slide()
	sync_movement.rpc(position, rotation, velocity, Time.get_ticks_msec())
	
func _process_remote_movement(delta):
	# Smooth movement with interplation
	var interpolated_pos = interpolation.interpolate(delta)
	position = Vector3(interpolated_pos.x, position.y, interpolated_pos.y)
	
	# Apply Gravity (only Y axis)
	if !is_on_floor() and not is_eliminated:
		velocity.y -= 9.8 * delta
		move_and_slide()

@rpc("any_peer", "call_local", "unreliable")
func sync_movement(new_position: Vector3, new_rotation: Vector3, new_velocity: Vector3, timestamp: int):
	if is_multiplayer_authority(): return
	
	# Calculate latency
	var current_time = Time.get_ticks_msec()
	network_latency = (current_time - timestamp) / 1000.0
	
	# New Interpolation target
	interpolation.update_target(
		Vector2(new_position.x, new_position.z),
		Vector2(new_velocity.x, new_velocity.z),
		network_latency
	)
	
	rotation = new_rotation
	position.y = new_position.y
	velocity = new_velocity

@rpc("any_peer")
func rpc_update_animations(is_walking, progress) -> void:
	# Update Animation at all clients
	if is_walking:
		animation_tree.set("parameters/blend_position",1.0 - movement_curve.sample(progress))
	else:
		animation_tree.set("parameters/blend_position",1.0 - movement_curve2.sample(progress))

func update_animations():
	var is_walking = velocity.length() > 1.0
	
	if is_walking:
		animation_tree.set("parameters/blend_position",1.0 - movement_curve.sample(acceleration_progress))
		rpc_update_animations.rpc(is_walking,acceleration_progress)
	else:
		animation_tree.set("parameters/blend_position",1.0 - movement_curve2.sample(deceleration_progress))
		rpc_update_animations.rpc(is_walking,deceleration_progress)

func  _get_hand_position():
	return hand.global_position

func _on_timer_timeout() -> void:
	is_game_started = false
