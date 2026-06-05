extends Node

enum {
	INIT,
	HOST_IDLE,
	HOST_SENT_ANSWER,
	HOST_STARTED,
	PEER_JOINED,
	PEER_SENT_OFFER,
	PEER_STARTED
}

const DEFAULT_TURN_SERVER_URLS = [ "turn:127.0.0.1:3478" ]
const TURN_SERVER_URLS_ENV = "TURN_SERVER_URLS"
const TURN_SERVER_USERNAME_ENV = "TURN_SERVER_USERNAME"
const TURN_SERVER_PASSWORD_ENV = "TURN_SERVER_PASSWORD"

var state = INIT

const SignalingClient = preload("res://signal.gd")
var _signal = SignalingClient.new()

var _peer = null# WebRTCPeerConnection.new()

var _channel = null
var _channel_ready = false
var _connection_timer = Timer.new()

@export var turn_server_urls: Array = DEFAULT_TURN_SERVER_URLS
@export var turn_server_username: String = "tojam-2021"
@export var turn_server_credential: String = "tojam-2021"

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
	if not _ensure_peer():
		emit_signal("on_closed")
		return
	_set_state(HOST_IDLE)
	_signal.connect_to_room(game_id)

func join_game(game_id):
	if not _ensure_peer():
		emit_signal("on_closed")
		return
	_set_state(PEER_JOINED)
	_signal.connect_to_room(game_id)

func send_message(message):
	if _channel == null:
		return
	_channel.put_packet(JSON.stringify(message).to_utf8_buffer())

# Called when the node enters the scene tree for the first time.
func _ready():
	_connection_timer.autostart = false
	_connection_timer.one_shot = true
	_connection_timer.connect("timeout", Callable(self, "_on_timeout"))

	_signal.connect("on_connected", Callable(self, "_on_connected"))
	_signal.connect("on_message", Callable(self, "_on_message"))
	_signal.connect("on_closed", Callable(self, "_on_closed"))

	self.add_child(_connection_timer)
	self.add_child(_signal)
	set_process(false)


func _process(_delta):
	if _peer == null or _channel == null:
		return
	_peer.poll()
	if _channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		if _channel_ready == false:
			_channel_ready = true
			_on_data_channel_ready()
		while _channel.get_available_packet_count() > 0:
			var test_json_conv = JSON.new()
			test_json_conv.parse(_channel.get_packet().get_string_from_utf8())
			var message = test_json_conv.get_data()
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
			var host_remote_err = _peer.set_remote_description(payload["type"], payload["sdp"])
			if host_remote_err != OK:
				print("Error = ", host_remote_err)
				print_stack()
			print("host set remote description")
		[PEER_SENT_OFFER, "host_answer"]:
			var peer_remote_err = _peer.set_remote_description(payload["type"], payload["sdp"])
			if peer_remote_err != OK:
				print("Error = ", peer_remote_err)
				print_stack()
			print("peer set remote description")
		[HOST_SENT_ANSWER, "peer_ice_candidate"]:
			while len(_candidates) > 0:
				var queued_peer_payload = _candidates.pop_back()
				var queued_peer_candidate_err = _peer.add_ice_candidate(queued_peer_payload["media"], queued_peer_payload["index"], queued_peer_payload["name"])
				if queued_peer_candidate_err != OK:
					print("Error = ", queued_peer_candidate_err)
					print_stack()
			var peer_candidate_err = _peer.add_ice_candidate(payload["media"], payload["index"], payload["name"])
			if peer_candidate_err != OK:
				print("Error = ", peer_candidate_err)
				print_stack()
			print("host added ice candidate")
		[PEER_SENT_OFFER, "host_ice_candidate"]:
			while len(_candidates) > 0:
				var queued_host_payload = _candidates.pop_back()
				var queued_host_candidate_err = _peer.add_ice_candidate(queued_host_payload["media"], queued_host_payload["index"], queued_host_payload["name"])
				if queued_host_candidate_err != OK:
					print("Error = ", queued_host_candidate_err)
					print_stack()
			var host_candidate_err = _peer.add_ice_candidate(payload["media"], payload["index"], payload["name"])
			if host_candidate_err != OK:
				print("Error = ", host_candidate_err)
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

func _on_session_description_created(sdp_type, sdp):
	match state:
		PEER_JOINED:
			var peer_local_err = _peer.set_local_description(sdp_type, sdp)
			if peer_local_err != OK:
				print("Error = ", peer_local_err)
				print_stack()
			_signal.send_message("peer_offer", {
				"type": sdp_type,
				"sdp": sdp
			})
			_set_state(PEER_SENT_OFFER)
			print("peer sent session description")
		HOST_IDLE:
			var host_local_err = _peer.set_local_description(sdp_type, sdp)
			if host_local_err != OK:
				print("Error = ", host_local_err)
				print_stack()
			_signal.send_message("host_answer", {
				"type": sdp_type,
				"sdp": sdp
			})
			_set_state(HOST_SENT_ANSWER)
			print("host sent session description")
			_connection_timer.start(5)
		_:
			print("Unhandled _on_session_description_created state = ", state, " type = ", sdp_type)

func _on_ice_candidate_created(media, index, candidate_name):
	match state:
		PEER_SENT_OFFER:
			_signal.send_message("peer_ice_candidate", {
				"media": media,
				"index": index,
				"name": candidate_name
			})
			print("peer sent ice candidate")
		HOST_SENT_ANSWER:
			_signal.send_message("host_ice_candidate", {
				"media": media,
				"index": index,
				"name": candidate_name
			})
			print("host sent ice candidate")
		_:
			print("Unhandled _on_ice_candidate_created state = ", state, " name = ", candidate_name)

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

func _ensure_peer() -> bool:
	if _peer != null and _channel != null:
		return true

	_peer = WebRTCPeerConnection.new()
	if _peer == null:
		push_warning("WebRTC peer is unavailable.")
		return false

	_configure_turn_servers()
	_peer.connect("session_description_created", Callable(self, "_on_session_description_created"))
	_peer.connect("ice_candidate_created", Callable(self, "_on_ice_candidate_created"))

	var ice_server_configuration = {
		"iceServers": [{
			"urls": turn_server_urls # One or more TURN servers.
		}]
	}

	# Username and credential are optional for public TURN server setups.
	if turn_server_username != "":
		ice_server_configuration["iceServers"][0]["username"] = turn_server_username
	if turn_server_credential != "":
		ice_server_configuration["iceServers"][0]["credential"] = turn_server_credential

	var initialize_err = _peer.initialize(ice_server_configuration)
	if initialize_err != OK:
		push_warning("Unable to initialize WebRTC peer: %s" % initialize_err)
		_peer = null
		return false

	_channel = _peer.create_data_channel("chat", {
		"negotiated": true,
		"id": 1
	})
	if _channel == null:
		push_warning("Unable to create WebRTC data channel.")
		_peer = null
		return false

	set_process(true)
	return true

func _configure_turn_servers():
	turn_server_urls = _read_turn_server_urls_from_env()
	turn_server_username = _read_env_value(TURN_SERVER_USERNAME_ENV, turn_server_username)
	turn_server_credential = _read_env_value(TURN_SERVER_PASSWORD_ENV, turn_server_credential)

func _read_turn_server_urls_from_env() -> Array:
	var env_value = OS.get_environment(TURN_SERVER_URLS_ENV)
	if env_value == "":
		return turn_server_urls if turn_server_urls.size() > 0 else DEFAULT_TURN_SERVER_URLS

	var parsed_urls = []
	for url in env_value.split(",", false):
		var trimmed = url.strip_edges()
		if trimmed != "":
			parsed_urls.append(trimmed)
	return parsed_urls if parsed_urls.size() > 0 else DEFAULT_TURN_SERVER_URLS

func _read_env_value(key: String, fallback: String) -> String:
	var value = OS.get_environment(key)
	return value if value != "" else fallback
