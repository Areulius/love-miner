extends CharacterBody3D

var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.002
const GRAVITY = 12

var pitch = 0.0

# View bobbing
const BOB_FREQ = 2.0
const BOB_AMP = 0.05
var t_bob = 0.0

# FOV
const BASE_FOV = 75
const FOV_CHANGE = 1.05


@onready var head = $Head
@onready var camera = $Head/Camera3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var spawn_name := GameManager.get_pending_spawn()
	
	if spawn_name != "":
		# Find the marker in this scene and move there
		var spawn_point := get_tree().get_root().find_child(spawn_name, true, false)
		if spawn_point:
			global_position = spawn_point.global_position

func _unhandled_input(event):
	# Mouse input
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY)

		pitch -= event.relative.y * SENSITIVITY
		pitch = clamp(pitch, -1.5, 1.5)
		head.rotation.x = pitch

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Sprint
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Movement
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 10)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 10)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 4)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 4)
		
	# Smooth view bobbing
	var target_bob = Vector3.ZERO
	if input_dir.length() > 0 and is_on_floor():
		t_bob += delta * speed
		target_bob = _headbob(t_bob)
	camera.transform.origin = camera.transform.origin.lerp(target_bob, delta * 10)

	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 10)


	move_and_slide()
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = sin(time * BOB_FREQ / 2) * BOB_AMP
	return pos
