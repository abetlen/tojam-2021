extends Spatial

export var ANGULAR_VELOCITY = 5
export var MAX_ANGULAR_VELOCITY = 20

export var LINEAR_VELOCITY = 5
export var MAX_LINEAR_VELOCITY = 20

# Called when the node enters the scene tree for the first time.
func _ready():
	var player = $Player
	var target = $Track/PathFollow
	player.global_transform.origin = target.global_transform.origin

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var player = $Player
	var target = $Track/PathFollow

	var v = (target.global_transform.origin - player.global_transform.origin)
	player.linear_velocity = 20 * v

func get_track_position() -> float:
	var target = $Track/PathFollow
	return target.get_unit_offset()

func set_track_position(position: float):
	var target = $Track/PathFollow
	target.set_unit_offset(clamp(position, 0, 1))

func get_orientation() -> float:
	var player = $Player
	return player.rotation.y

func set_orientation(orientation: float):
	$Player.rotation = orientation

func move_forward(delta):
	self.set_track_position(clamp(self.get_track_position() + 1 * delta, 0, 1))

func move_backward(delta):
	self.set_track_position(clamp(self.get_track_position() - 1 * delta, 0, 1))

func turn_clockwise(delta):
	var player = $Player
	player.angular_velocity.y -= 365 * delta
	player.angular_velocity.y = clamp(player.angular_velocity.y, -MAX_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY)

func turn_counter_clockwise(delta):
	var player = $Player
	player.angular_velocity.y += 365 * delta
	player.angular_velocity.y = clamp(player.angular_velocity.y, -MAX_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY)

func get_state():
	var player = $Player
	return [player.transform.origin.x, player.transform.origin.z, player.rotation.y]

func set_state(state):
	var player = $Player
	player.transform.origin.x = state[0]
	player.transform.origin.z = state[1]
	player.rotation.y = state[2]
