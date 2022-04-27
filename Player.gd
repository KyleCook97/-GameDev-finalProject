
extends KinematicBody

var carried_object = null
var throw_power = 0

var interactor = null

# Movement
const IDLE = 0

const RUN = 1 # default movement
const SPRINT = 2
const WALK = 3

var movement_state = IDLE

const STAND = 0
const CROUCH = 1

var posture_state = STAND

var run_speed = 8
var sprint_speed = 10
var walk_speed = 2.7

var move_speed = run_speed

# Controls
var velocity = Vector3()
var yaw = 0
var pitch = 0
var is_moving = false
var view_sensitivity = 0.15

var look_vector = Vector3()

# Physics
var gravity = -40

const ACCEL = 0.5
const DEACCEL = 0.8

const JUMP_STR = 15

#slope variables
const MAX_SLOPE_ANGLE = 60

#stair variables
const MAX_STAIR_SLOPE = 20
const STAIR_JUMP_HEIGHT = 6


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(d):

#######################################################################################################
# INTERACTIONS

	if $Yaw/Camera/InteractionRay.is_colliding():
		var x = $Yaw/Camera/InteractionRay.get_collider()
		if x.has_method("pick_up"):
			$interaction_text.set_text("[F]  Pick up: " + x.get_name())
		elif x.has_method("interact"):
			$interaction_text.set_text("[E]  Interact with: " + x.get_name())
		else:
			$interaction_text.set_text("")
	else:
		$interaction_text.set_text("")


#######################################################################################################
# VECTOR 3 for where the player is currently looking

	var dir = (get_node("Yaw/Camera/look_at").get_global_transform().origin - get_node("Yaw/Camera").get_global_transform().origin).normalized()
	look_vector = dir


func _physics_process(delta):
	_process_movements(delta)

#######################################################################################################
# NORMAL MOVEMENT
#######################################################################################################

var direction = Vector3()
func _process_movements(delta):

	var up = Input.is_action_pressed("ui_up")
	var down = Input.is_action_pressed("ui_down")
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")

	var jump = Input.is_action_pressed("jump")
	
	var sprint = Input.is_action_pressed("sprint")
	var walk = Input.is_action_pressed("walk")

	var aim = $Yaw/Camera.get_camera_transform().basis

	direction = Vector3()

	if up:
		direction -= aim[2]
	if down:
		direction += aim[2]
	if left:
		direction -= aim[0]
	if right:
		direction += aim[0]

	if up or right or left or down: # IS MOVING?
		if posture_state == STAND:
			movement_state = RUN
			move_speed = run_speed
			if up or right or left: # IS MOVING FORWARDS?
				if sprint:
					movement_state = SPRINT
					move_speed = sprint_speed	
				elif walk:
					movement_state = WALK
					move_speed = walk_speed
		else:
			movement_state = WALK
			move_speed = walk_speed
	else: # IS NOT MOVING?
		movement_state = IDLE

	var normal = $floor_check.get_collision_normal()

	if is_on_floor():

		velocity = velocity - velocity.dot(normal) * normal

		if jump:
			if movement_state == SPRINT:
				velocity.y += JUMP_STR * 1.1 # Jump higher if sprinting
			else:
				velocity.y += JUMP_STR

	else:
		_apply_gravity(delta)

	if velocity.x > 0 or velocity.x < 0 and is_moving == false:
		is_moving = true
	else:
		is_moving = false
	if velocity.y > 0 or velocity.y < 0 and is_moving == false:
		is_moving = true
	else:
		is_moving = false
	if velocity.z > 0 or velocity.z < 0 and is_moving == false:
		is_moving = true
	else:
		is_moving = false
		pass

	direction.y = 0
	#Normalize direction
	direction = direction.normalized()

	var hvel = velocity
	hvel.y = 0
	var target = direction * move_speed
	var accel
	if(direction.dot(hvel) > 0):
		accel = ACCEL
	else:
		accel = DEACCEL

	hvel = hvel.linear_interpolate(target, accel * move_speed * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z

	velocity = move_and_slide(velocity, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

	throwing(delta)

#######################################################################################################
# GRAVITY

func _apply_gravity(delta):
	velocity.y += delta * gravity

#######################################################################################################
# CAMERA MOVEMENTS

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		yaw = fmod(yaw - event.relative.x * view_sensitivity, 360)
		pitch = max(min(pitch - event.relative.y * view_sensitivity, 89), -89)
		$Yaw.rotation = Vector3(0, deg2rad(yaw), 0)
		$Yaw/Camera.rotation = Vector3(deg2rad(pitch), 0, 0)


#######################################################################################################
# BUTTON PRESSING
#######################################################################################################
func _input(event):

	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()

	# If already carries an object - release it, otherwise (if ray is colliding) pick an object up
	if event.is_action_pressed("pick_up"):
		if carried_object != null:
			carried_object.pick_up(self)
		else:
			if $Yaw/Camera/InteractionRay.is_colliding():
				var x = $Yaw/Camera/InteractionRay.get_collider()
				if x.has_method("pick_up"):
					x.pick_up(self)

	# Hold Left Mouse Button (LMB) to throw carried object
	if event.is_action_released("throw"):
		if carried_object != null:
			carried_object.throw(throw_power)
		throw_power = 0

	# Interact
	if event.is_action_pressed("interact"):
		if $Yaw/Camera/InteractionRay.is_colliding():
			var x = $Yaw/Camera/InteractionRay.get_collider()
			print("COLLIDING")
			print(x.get_name())
			if x.has_method("interact"):
				x.interact(self)


	# Crouching

	# Already crouching?
		# Is there ceiling above me? If not then stand. If yes, then display a message.

	if event.is_action_pressed("crouch"):
		if posture_state == STAND:
			$crouching.play("crouch")
			move_speed = walk_speed
		else:
			if !($ceiling_check.is_colliding()):
				$crouching.play_backwards("crouch")
				move_speed = run_speed
			else:
				show_message("I cannot stand here.", 2)

#######################################################################################################
# OTHER
#######################################################################################################

# CROUCHING ANIM
func _on_crouching_animation_finished(anim_name):
	if posture_state == STAND:
		posture_state = CROUCH
	else:
		posture_state = STAND

# IMPULSE STUFF
func impulse(vector_towards, power, time):
	for x in range(time * 100):
		velocity += vector_towards * Vector3(power, power, power)

# THROW STUFF
func throwing(delta):
	if carried_object != null:
		if Input.is_action_pressed("throw"):
			if throw_power <= 250:
				throw_power += 2

# SHOW A MESSAGE ON SCREEN
func show_message(text, time):
	$message.set_text(text)
	$message/Timer.set_wait_time(time)
	$message/Timer.start()
	yield($message/Timer, "timeout")
	$message.set_text("")
