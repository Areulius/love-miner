extends CharacterBody3D

@onready var debug_label: Label = $"CanvasLayer/DebugLabel"

# Physics
const GRAVITY: float = 12.0

# Walking
const WALK_SPEED: float = 5.0
const JUMP_VELOCITY: float = 4.5
var speed: float = 0.0

# Sprinting
const SPRINT_SPEED: float = 8.0
var is_sprinting: bool = false

# Camera
const SENSITIVITY: float = 0.0015
var pitch: float = 0.0

@onready var head = $Head
@onready var camera = $Head/Camera3D

# Crouching
const CROUCH_SPEED: float = 3.0

const STAND_HEIGHT: float = 2.0
const STAND_HEAD_Y: float = 1.6
const CROUCH_HEIGHT: float = 1.0
const CROUCH_HEAD_Y: float = 0.8

var is_crouching: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Sliding
const SLIDE_BOOST: float = 3.0
const SLIDE_MAX_SPEED: float = 12.0
const SLIDE_MIN_SPEED: float = 3.0
const SLIDE_FRICTION: float = 1.0
var is_sliding: bool = false

@onready var slide_particles: GPUParticles3D = $SlideParticles

# LERP speeds
const LERP_SPEED_MOVEMENT_GROUND: float = 10.0
const LERP_SPEED_MOVEMENT_AIR: float = 4.0
const LERP_SPEED_CAMERA_FOV: float = 12.0
const LERP_SPEED_CROUCH: float = 15.0

# View Bob
const BOB_FREQ: float = 2.0
const BOB_AMP: float = 0.05
var t_bob: float = 0.0

# FOV
const BASE_FOV: float = 75
const FOV_CHANGE: float = 1.01

# Coyote Time
const COYOTE_TIME: float = 0.15
var coyote_timer: float = 0.0

# Jump Buffer
const JUMP_BUFFER_TIME: float = 0.15
var jump_buffer_timer: float = 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_spawn_point()

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		_rotate_camera(event)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_tick_jump_buffer(delta)
	_handle_jump()
	_handle_sprinting()
	_handle_crouch(delta)
	_handle_movement(delta)
	_handle_sliding(delta)
	_update_head_bob(delta)
	_update_fov(delta)
	_update_slide_particles()
	move_and_slide()
	_update_debug_hud()

# -- Camera --
func _rotate_camera(event):
		rotate_y(-event.relative.x * SENSITIVITY)

		pitch -= event.relative.y * SENSITIVITY
		pitch = clamp(pitch, -1.5, 1.5)
		head.rotation.x = pitch

# -- Gravity --
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
		velocity.y -= GRAVITY * delta

# -- Jumping --
func _handle_jump() -> void:
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

func _tick_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

# -- Movement --
func _handle_movement(delta: float) -> void:
	if is_sliding:
		return

	if is_crouching:
		speed = CROUCH_SPEED
	elif is_sprinting:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var blend := delta * LERP_SPEED_MOVEMENT_GROUND if is_on_floor() else delta * LERP_SPEED_MOVEMENT_AIR

	velocity.x = lerp(velocity.x, direction.x * speed, blend)
	velocity.z = lerp(velocity.z, direction.z * speed, blend)

# -- Sprinting --
func _handle_sprinting() -> void:
	if Input.is_action_pressed("sprint") and not is_crouching:
		is_sprinting = true 
	else:
		is_sprinting = false

# -- Crouching --
func _handle_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch")

	if wants_crouch and not is_crouching:
		_enter_crouch()
	elif not wants_crouch and is_crouching and _can_stand_up():
		_exit_crouch()

	# Smoothly resize collision and move head
	var target_height := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var target_head_y := CROUCH_HEAD_Y if is_crouching else STAND_HEAD_Y
	var target_shape_y := CROUCH_HEIGHT / 2.0 if is_crouching else STAND_HEIGHT / 2.0

	collision_shape.shape.height = lerpf(collision_shape.shape.height, target_height, delta * LERP_SPEED_CROUCH)
	collision_shape.position.y = lerpf(collision_shape.position.y, target_shape_y, delta * LERP_SPEED_CROUCH)
	head.position.y = lerpf(head.position.y, target_head_y, delta * LERP_SPEED_CROUCH)

func _enter_crouch() -> void:
	is_crouching = true
	if is_on_floor() and is_sprinting:
		_enter_slide()

func _exit_crouch() -> void:
	is_crouching = false
	is_sliding = false

func _can_stand_up() -> bool:
	var space_state := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * (CROUCH_HEIGHT / 2.0),
		global_position + Vector3.UP * STAND_HEIGHT,
		collision_mask
	)
	# Exclude the player itself from the raycast
	ray.exclude = [self]
	var result := space_state.intersect_ray(ray)
	return result.is_empty()

# -- Sliding --
func _handle_sliding(delta: float) -> void:
	if not is_sliding:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < SLIDE_MIN_SPEED or not is_on_floor():
		is_sliding = false
		return

	velocity.x = lerpf(velocity.x, 0.0, delta * SLIDE_FRICTION)
	velocity.z = lerpf(velocity.z, 0.0, delta * SLIDE_FRICTION)

func _enter_slide() -> void:
	is_sliding = true
	var move_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var current_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var slide_speed := minf(current_speed + SLIDE_BOOST, SLIDE_MAX_SPEED)
	velocity.x = move_dir.x * slide_speed
	velocity.z = move_dir.z * slide_speed

# -- Slide Particles --
func _update_slide_particles() -> void:
	slide_particles.emitting = is_sliding and is_on_floor()

# -- FOV --
# change only on horizontal movement
func _update_fov(delta: float) -> void:
	var hor_vel := Vector2(velocity.x, velocity.z).length()
	var velocity_clamped : float = clamp(hor_vel, 0.5, SPRINT_SPEED)
	var target_fov : float = BASE_FOV + FOV_CHANGE * velocity_clamped
	if is_sliding:
		target_fov += 3.0
	camera.fov = lerp(camera.fov, target_fov, delta * LERP_SPEED_CAMERA_FOV)

# -- Head Bob --
func _update_head_bob(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var target_bob := Vector3.ZERO

	if input_dir.length() > 0 and is_on_floor():
		t_bob += delta * speed
		target_bob = _calculate_head_bob(t_bob)

	camera.transform.origin = camera.transform.origin.lerp(target_bob, delta * LERP_SPEED_CAMERA_FOV)

func _calculate_head_bob(time: float) -> Vector3:
	return Vector3(
		sin(time * BOB_FREQ / 2.0) * BOB_AMP,
		sin(time * BOB_FREQ) * BOB_AMP,
		0.0)

# -- Spawn Point --
func _setup_spawn_point():
	var spawn_name: String = GameManager.get_pending_spawn()
	
	if spawn_name == "":
		return
	# Find the marker in this scene and move there
	var spawn_point := get_tree().get_root().find_child(spawn_name, true, false)
	if spawn_point:
		global_position = spawn_point.global_position

# -- Debug --
func _update_debug_hud() -> void:
	var hvel := Vector2(velocity.x, velocity.z).length()
	debug_label.text = "Speed: %.2f\nVertical: %.2f\nsprinting: %s\ncrouching: %s\nsliding: %s" % [hvel, velocity.y, is_sprinting, is_crouching, is_sliding]
