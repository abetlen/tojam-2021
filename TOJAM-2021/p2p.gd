extends Node

enum {
	INIT,
	HOST_IDLE,
	HOST_SENT_ANSWER,
	HOST_STARTED,
	PEER_JOINED,
	PEER_SENT_OFFER
	PEER_STARTED
}

var state = INIT

const Signal = preload("res://signal.gd")
var _signal = Signal.new()

var _peer = null# WebRTCPeerConnection.new()

var _channel = null
var _channel_ready = false
var _connection_timer = Timer.new()

signal state_changed(old_state, new_state)

signal on_ready
signal on_message(message)
signal on_closed

var _candidates = []

func _set_state(_state):
	var old_state = state
	state = _state
	emit_signal("state_changed", old_state, state)

func host_game(game_id):
	_set_state(HOST_IDLE)
	_signal.connect_to_room(game_id)

func join_game(game_id):
	_set_state(PEER_JOINED)
	_signal.connect_to_room(game_id)

func send_message(message):
	_channel.put_packet(to_json(message).to_utf8())

# Called when the node enters the scene tree for the first time.
func _ready():
	_connection_timer.autostart = false
	_connection_timer.one_shot = true
	_connection_timer.connect("timeout", self, "_on_timeout")

	_signal.connect("on_connected", self, "_on_connected")
	_signal.connect("on_message", self, "_on_message")
	_signal.connect("on_closed", self, "_on_closed")

	_peer = WebRTCPeerConnection.new()
	_peer.connect("session_description_created", self, "_on_session_description_created")
	_peer.connect("ice_candidate_created", self, "_on_ice_candidate_created")

	var err = _peer.initialize({
		"iceServers": [{
			"urls": [ "turn:tojam-2021.insert-mode.dev:3478" ], # One or more TURN servers.
			"username": "tojam-2021", # Optional username for the TURN server.
			"credential": "tojam-2021", # Optional password for the TURN server.
		}]
	})
	if err != OK:
		print("Error = ", err)
		print_stack()
	_channel = _peer.create_data_channel("chat", {
		"negotiated": true, 
		"id": 1
	})

	self.add_child(_connection_timer)
	self.add_child(_signal)


func _process(delta):
	_peer.poll()
	if _channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		if _channel_ready == false:
			_channel_ready = true
			_on_data_channel_ready()
		while _channel.get_available_packet_count() > 0:
			var message = parse_json(_channel.get_packet().get_string_from_utf8())
			emit_signal("on_message", message)
	elif _peer.get_connection_state() in [WebRTCPeerConnection.STATE_CLOSED, WebRTCPeerConnection.STATE_DISCONNECTED, WebRTCPeerConnection.STATE_FAILED]:
		_on_closed()

func _on_connected():
	match state:
		HOST_IDLE:
			print("host connected")
		PEER_JOINED:
			print("peer connected")
			_peer.create_offer()

func _on_message(topic, payload):
	match [state, topic]:
		[HOST_IDLE, "peer_offer"]:
			var err = _peer.set_remote_description(payload["type"], payload["sdp"])
			if err != OK:
				print("Error = ", err)
				print_stack()
			print("host set remote description")
		[PEER_SENT_OFFER, "host_answer"]:
			var err = _peer.set_remote_description(payload["type"], payload["sdp"])
			if err != OK:
				print("Error = ", err)
				print_stack()
			print("peer set remote description")
		[HOST_SENT_ANSWER, "peer_ice_candidate"]:
			while len(_candidates) > 0:
				var _payload = _candidates.pop_back()
				var err = _peer.add_ice_candidate(_payload["media"], _payload["index"], _payload["name"])
				if err != OK:
					print("Error = ", err)
					print_stack()
			var err = _peer.add_ice_candidate(payload["media"], payload["index"], payload["name"])
			if err != OK:
				print("Error = ", err)
				print_stack()
			print("host added ice candidate")
		[PEER_SENT_OFFER, "host_ice_candidate"]:
			while len(_candidates) > 0:
				var _payload = _candidates.pop_back()
				var err = _peer.add_ice_candidate(_payload["media"], _payload["index"], _payload["name"])
				if err != OK:
					print("Error = ", err)
					print_stack()
			var err = _peer.add_ice_candidate(payload["media"], payload["index"], payload["name"])
			if err != OK:
				print("Error = ", err)
				print_stack()
			print("peer added ice candidate")
		[_, "peer_ice_candidate"]:
			if state != HOST_SENT_ANSWER:
				_candidates.push_back(payload)
		[_, "host_ice_candidate"]:
			if state != PEER_SENT_OFFER:
				_candidates.push_back(payload)
		_:
			print("Unhandled _on_message state = ", state, " topic = ", topic)

func _on_session_description_created(type, sdp):
	match state:
		PEER_JOINED:
			var err = _peer.set_local_description(type, sdp)
			if err != OK:
				print("Error = ", err)
				print_stack()
			_signal.send_message("peer_offer", {
				"type": type,
				"sdp": sdp
			})
			_set_state(PEER_SENT_OFFER)
			print("peer sent session description")
		HOST_IDLE:
			var err = _peer.set_local_description(type, sdp)
			if err != OK:
				print("Error = ", err)
				print_stack()
			_signal.send_message("host_answer", {
				"type": type,
				"sdp": sdp
			})
			_set_state(HOST_SENT_ANSWER)
			print("host sent session description")
			_connection_timer.start(5)
		_:
			print("Unhandled _on_session_description_created state = ", state, " type = ", type)

func _on_ice_candidate_created(media, index, name):
	match state:
		PEER_SENT_OFFER:
			_signal.send_message("peer_ice_candidate", {
				"media": media,
				"index": index,
				"name": name
			})
			print("peer sent ice candidate")
		HOST_SENT_ANSWER:
			_signal.send_message("host_ice_candidate", {
				"media": media,
				"index": index,
				"name": name
			})
			print("host sent ice candidate")
		_:
			print("Unhandled _on_ice_candidate_created state = ", state, " name = ", name)

func _on_data_channel_ready():
	match state:
		PEER_SENT_OFFER:
			_set_state(PEER_STARTED)
			emit_signal("on_ready")
		HOST_SENT_ANSWER:
			_set_state(HOST_STARTED)
			_connection_timer.stop()
			emit_signal("on_ready")
		_:
			print("Unhandled _on_data_channel_ready state = ", state)

func _on_closed():
	emit_signal("on_closed")

func _on_timeout():
	emit_signal("on_closed")
