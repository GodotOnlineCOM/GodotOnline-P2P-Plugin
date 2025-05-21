extends Camera3D

@export var target : Node3D  # Karakter referansı
@export var distance : float = 5.0
@export var min_distance : float = 1.0
@export var max_distance : float = 15.0
@export var zoom_speed : float = 2.0
@export var rotation_speed : float = 0.005
@export var vertical_angle_limit : Vector2 = Vector2(-PI/3, PI/3)

# Kamera açıları
var horizontal_angle : float = 0.0
var vertical_angle : float = 0.0

func _ready():
	if not target:
		target = get_parent()
	update_camera_position()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Sadece kamera açılarını güncelle
		horizontal_angle -= event.relative.x * rotation_speed
		vertical_angle -= event.relative.y * rotation_speed
		vertical_angle = clamp(vertical_angle, vertical_angle_limit.x, vertical_angle_limit.y)
		update_camera_position()
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				distance = clamp(distance - zoom_speed * event.factor, min_distance, max_distance)
				update_camera_position()
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = clamp(distance + zoom_speed * event.factor, min_distance, max_distance)
				update_camera_position()

func _process(delta):
	if target:
		update_camera_position()

func update_camera_position():
	if not target:
		return
	
	# Küresel koordinatlarda kamera pozisyonunu hesapla
	var offset = Vector3.ZERO
	offset.x = distance * sin(horizontal_angle) * cos(vertical_angle)
	offset.z = distance * cos(horizontal_angle) * cos(vertical_angle)
	offset.y = distance * sin(vertical_angle)
	
	global_transform.origin = target.global_transform.origin + offset
	look_at(target.global_transform.origin, Vector3.UP)
