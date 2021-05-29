extends RigidBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var INITIAL_LINEAR_VELOCITY = 20
export var MAX_LINEAR_VELOCITY = 150

signal scored_on(net)

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	self.reset_velocity()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func reset_velocity():
	self.linear_velocity.x = 0
	if (randi() % 2 == 0):
		self.linear_velocity.z = INITIAL_LINEAR_VELOCITY
	else:
		self.linear_velocity.z = -INITIAL_LINEAR_VELOCITY

func _physics_process(delta):
	var bodies = self.get_colliding_bodies()
	if len(bodies) > 0:
		var body = bodies[0]
		if body.name == "InNet":
			emit_signal("scored_on",  body)

	# Ensure the puck never stops
	if self.linear_velocity.length() < INITIAL_LINEAR_VELOCITY:
		self.linear_velocity = self.linear_velocity * 1.1
	elif self.linear_velocity.length() > MAX_LINEAR_VELOCITY:
		self.linear_velocity = self.linear_velocity * 0.9
