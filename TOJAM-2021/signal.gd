extends Node

export var websocket_url = "wss://tojam-2021.insert-mode.dev/rooms/%s"
const default_websocket_url = "wss://tojam-2021.insert-mode.dev/rooms/%s"
const signaling_server_url_env = "TOJAM_SIGNALING_WS_URL"
var _client = WebSocketClient.new()

var is_connected = false

signal on_connected
signal on_data(data)
signal on_message(topic, payload)
signal on_closed

# Lifecycle Methods

func _ready():
	websocket_url = _config_websocket_url()

func _process(delta):
	_client.poll()

func _config_websocket_url() -> String:
	var env_url = OS.get_environment(signaling_server_url_env)
	if env_url != "":
		return env_url
	return default_websocket_url if websocket_url.empty() else websocket_url

# Public Methods

func connect_to_room(id: String):
	_client.connect("connection_closed", self, "_on_closed")
	_client.connect("connection_error", self, "_on_closed")
	_client.connect("connection_established", self, "_on_connected")
	_client.connect("data_received", self, "_on_data")

	var url = websocket_url % id
	# Initiate connection to the given URL.
	var err = _client.connect_to_url(url)
	if err != OK:
		print("Unable to connect")
		set_process(false)

func send_message(topic: String, payload):
	_client.get_peer(1).put_packet(to_json({
		"topic": topic,
		"payload": to_json(payload)
	}).to_utf8())

# Private Methods

func _read_message() -> Dictionary:
	return parse_json(_client.get_peer(1).get_packet().get_string_from_utf8())

# Event Handlers

func _on_closed(was_clean : bool = false):
	print("Closed, clean: ", was_clean)
	set_process(false)
	is_connected = false
	emit_signal("on_closed")

func _on_connected(proto : String = ""):
	is_connected = true
	emit_signal("on_connected")

func _on_data():
	var message = _read_message()
	emit_signal("on_data", message)
	if message["type"] == "message":
		emit_signal("on_message", message["topic"], parse_json(message["payload"]))
