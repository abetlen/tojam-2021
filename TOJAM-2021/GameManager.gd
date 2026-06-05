extends Node

var _is_host = true

signal game_started
signal input_received(delta, inputs)
signal state_updated(state)
signal score_updated(home_score: int, away_score: int)

const P2P = preload("res://p2p.gd")
var p2p = P2P.new()

func send_message(topic, payload):
	p2p.send_message({
		"topic": topic,
		"payload": payload
	})

func _ready():
	p2p.connect("on_ready", Callable(self, "_on_ready"))
	p2p.connect("on_message", Callable(self, "_on_message"))
	p2p.connect("on_closed", Callable(self, "_on_closed"))
	self.add_child(p2p)

func _process(_delta):
	pass

func get_is_host() -> bool:
	return self._is_host

func set_is_host(is_host: bool):
	_is_host = is_host
	PhysicsServer3D.set_active(is_host)

func host_game(game_id: String):
	set_is_host(true)
	p2p.host_game(game_id)

func join_game(game_id: String):
	set_is_host(false)
	p2p.join_game(game_id)

func update_score(home_score: int, away_score: int):
	send_message("update_score", {
		"home": home_score,
		"away": away_score
	})

func update_state(puck, ho, hd, ao, ad):
	send_message("update_state", {
		"puck_position": [puck.x, puck.z],
		"home_offense": ho.get_state(),
		"home_defense": hd.get_state(),
		"away_offense": ao.get_state(),
		"away_defense": ad.get_state()
	})

func send_input(delta, inputs):
	send_message("input", {
		"delta": delta,
		"inputs": inputs
	})

func _on_ready():
	emit_signal("game_started")

func _on_message(message):
	if message["topic"] == "game_started":
		emit_signal("game_started")
	elif message["topic"] == "update_score":
		var score = message["payload"]
		emit_signal("score_updated", int(score["home"]), int(score["away"]))
	elif message["topic"] == "update_state":
		var state = message["payload"]
		emit_signal("state_updated", state)
	elif message["topic"] == "input":
		emit_signal("input_received", message["payload"]["delta"], message["payload"]["inputs"])
	else:
		print("Unhandled message: ", message)

func _on_closed():
	print("connection closed")
