extends Node3D

var homeScore: int = 0
var awayScore: int = 0

@export var ANGULAR_VELOCITY = 5
@export var MAX_ANGULAR_VELOCITY = 20

@export var LINEAR_VELOCITY = 5
@export var MAX_LINEAR_VELOCITY = 20

var last_score = Time.get_ticks_msec()
const NETWORK_SEND_HZ := 30.0
const NETWORK_SEND_INTERVAL := 1.0 / NETWORK_SEND_HZ
var _network_send_accumulator := 0.0
var _peer_input_delta_accumulator := 0.0

func _ready():
	GameManager.connect("score_updated", Callable(self, "_on_update_score"))
	GameManager.connect("state_updated", Callable(self, "_on_update_state"))
	GameManager.connect("input_received", Callable(self, "_on_input_received"))

func _set_score(home_score: int, away_score: int):
	homeScore = home_score
	awayScore = away_score
	$UI/Panel/HomeScore/Score.text = str(homeScore)
	$UI/Panel/AwayScore/Score.text = str(awayScore)

func _on_update_score(home_score, away_score):
	_set_score(int(home_score), int(away_score))

func _set_position(node, arr):
	node.transform.origin.x = arr[0]
	node.transform.origin.z = arr[1]

func _on_update_state(state):
	$Puck.transform.origin.x = state["puck_position"][0]
	$Puck.transform.origin.z = state["puck_position"][1]

	$HomeOffense.set_state(state["home_offense"])
	$HomeDefense.set_state(state["home_defense"])
	$AwayOffense.set_state(state["away_offense"])	
	$AwayDefense.set_state(state["away_defense"])

func _on_input_received(delta, inputs):
	var awayOffense = $AwayOffense
	var awayDefense = $AwayDefense

	if inputs["ui_up"]:
		awayDefense.move_backward(delta)
	elif inputs["ui_down"]:
		awayDefense.move_forward(delta)

	if inputs["ui_left"]:
		awayDefense.turn_counter_clockwise(delta)
	elif inputs["ui_right"]:
		awayDefense.turn_clockwise(delta)

	if inputs["ui_up_2"]:
		awayOffense.move_backward(delta)
	elif inputs["ui_down_2"]:
		awayOffense.move_forward(delta)

	if inputs["ui_left_2"]:
		awayOffense.turn_counter_clockwise(delta)
	elif inputs["ui_right_2"]:
		awayOffense.turn_clockwise(delta)

func input2dict(input):
	var keys = [
		"ui_up",
		"ui_down",
		"ui_left",
		"ui_right",
		"ui_up_2",
		"ui_down_2",
		"ui_left_2",
		"ui_right_2",
	]
	var inputs = {}
	for key in keys:
		inputs[key] = input.is_action_pressed(key)
	return inputs

func process_host_input(delta):
	var homeOffense = $HomeOffense
	var homeDefense = $HomeDefense
	var awayOffense = $AwayOffense
	var awayDefense = $AwayDefense

	if Input.is_action_pressed("ui_up"):
		homeOffense.move_forward(delta)
	elif Input.is_action_pressed("ui_down"):
		homeOffense.move_backward(delta)

	if Input.is_action_pressed("ui_left"):
		homeOffense.turn_counter_clockwise(delta)
	elif Input.is_action_pressed("ui_right"):
		homeOffense.turn_clockwise(delta)

	if Input.is_action_pressed("ui_up_2"):
		homeDefense.move_forward(delta)
	elif Input.is_action_pressed("ui_down_2"):
		homeDefense.move_backward(delta)

	if Input.is_action_pressed("ui_left_2"):
		homeDefense.turn_counter_clockwise(delta)
	elif Input.is_action_pressed("ui_right_2"):
		homeDefense.turn_clockwise(delta)

func send_host_state():
	GameManager.update_state($Puck.transform.origin, $HomeOffense, $HomeDefense, $AwayOffense, $AwayDefense)

func process_peer_input(delta):
	GameManager.send_input(delta, input2dict(Input))

func _process(delta):
	_network_send_accumulator += delta
	if not GameManager.get_is_host():
		_peer_input_delta_accumulator += delta

	var should_send_network_update := false
	if _network_send_accumulator >= NETWORK_SEND_INTERVAL:
		_network_send_accumulator = fmod(_network_send_accumulator, NETWORK_SEND_INTERVAL)
		should_send_network_update = true

	if GameManager.get_is_host():
		process_host_input(delta)
		if should_send_network_update:
			send_host_state()
	else:
		if should_send_network_update:
			process_peer_input(_peer_input_delta_accumulator)
			_peer_input_delta_accumulator = 0.0

	var puck = $Puck
	if abs(puck.transform.origin.x) > 45 or abs(puck.transform.origin.z) > 105:
		_reset_game()

func _on_Puck_scored_on(net):
	var now = Time.get_ticks_msec()
	if now - last_score < 100:
		return
	else:
		last_score = now

	var homeNet = $HomeNet/InNet
	if net == homeNet:
		_set_score(homeScore, awayScore + 1)
	else:
		_set_score(homeScore + 1, awayScore)
	GameManager.update_score(homeScore, awayScore)

	_reset_game()

func _reset_game():
	var puck = $Puck
	puck.transform.origin.x = 0
	puck.transform.origin.z = 0
	puck.reset_velocity()

	$HomeOffense/Track/PathFollow3D.progress_ratio = 0.5
	$HomeDefense/Track/PathFollow3D.progress_ratio = 0.5
	$AwayOffense/Track/PathFollow3D.progress_ratio = 0.5
	$AwayDefense/Track/PathFollow3D.progress_ratio = 0.5
	
	
