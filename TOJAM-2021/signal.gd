extends Node

@export var websocket_url = "ws://localhost:5050/rooms/%s"
const default_websocket_url = "ws://localhost:5050/rooms/%s"
const signaling_server_url_env = "SIGNALING_WS_URL"
var _client = WebSocketPeer.new()

var _connected = false
var _was_open = false

signal on_connected
signal on_data(data)
signal on_message(topic, payload)
signal on_closed

# Lifecycle Methods

func _ready():
	websocket_url = _config_websocket_url()
	set_process(false)

func _process(_delta):
	_client.poll()
	var state = _client.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				_connected = true
				emit_signal("on_connected")
			while _client.get_available_packet_count() > 0:
				_on_data()
		WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
			if _connected or _was_open:
				_on_closed(false)
		_:
			pass

func _config_websocket_url() -> String:
	var env_url = OS.get_environment(signaling_server_url_env)
	if env_url != "":
		return env_url
	return default_websocket_url if websocket_url.is_empty() else websocket_url

# Public Methods

func connect_to_room(id: String):
	var url = websocket_url % id
	var connect_err = _client.connect_to_url(url)
	if connect_err != OK:
		print("Unable to connect")
		set_process(false)
		return
	set_process(true)

func send_message(topic: String, payload):
	if not _connected:
		return
	_client.put_packet(JSON.stringify({
		"topic": topic,
		"payload": JSON.stringify(payload)
	}).to_utf8_buffer())

# Private Methods

func _read_message() -> Dictionary:
	var parsed = JSON.parse_string(_client.get_packet().get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

# Event Handlers

func _on_closed(was_clean : bool = false):
	print("Closed, clean: ", was_clean)
	set_process(false)
	_connected = false
	_was_open = false
	emit_signal("on_closed")

func _on_connected(_proto : String = ""):
	_connected = true
	emit_signal("on_connected")

func _on_data():
	var message = _read_message()
	emit_signal("on_data", message)
	if message.has("type") and message["type"] == "message":
		emit_signal("on_message", message["topic"], JSON.parse_string(message["payload"]))
