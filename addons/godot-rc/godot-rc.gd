@tool
class_name GodotRC
extends Node

var server: WebSocketServer
var commands := []


func _init() -> void:
	server = WebSocketServer.new()
	add_child(server)
	server.listen(6500)
	server.message_received.connect(on_message)
	server.client_connected.connect(on_connected)


func _exit_tree() -> void:
	server.stop()
	server.queue_free()


func register_command(command_name: String, callable: Callable, with_response: bool = false):
	for command in commands:
		if command[0] == command_name:
			Log.WARN('[GodotRC] Tried to register command "' + command_name + '" twice.')
			return

	commands.push_back([command_name, callable, with_response])


func on_connected(peer_id: int) -> void:
	Log.INFO("[GodotRC] Client connected: " + str(peer_id))


func on_message(peer_id: int, _message: String) -> void:
	var message: String = _message.strip_edges()
	Log.TRACE("[GodotRC] Received message: " + message)
	var parsed: Dictionary = JSON.parse_string(message)
	var params = parsed.params
	var response = null
	var known_method: bool = false
	for method in commands:
		var method_name: String = method[0]
		if parsed.method == method_name:
			known_method = true
			var callable: Callable = method[1]
			var with_response: bool = method[2]
			match [with_response, params == null]:
				[false, false]:
					callable.call(params)
				[false, true]:
					callable.call()
				[true, false]:
					response = callable.call(params)
				[true, true]:
					response = callable.call()
	if not known_method:
		Log.WARN("[GodotRC] Received unknown message: " + message)
	if response != null:
		send_response(peer_id, response, parsed.id)


func send_response(peer_id: int, data, response_id: int):
	server.send(peer_id, JSON.stringify({"result": data, "id": response_id}))


func send_notification(peer_id: int, name: String, data):
	Log.TRACE("[GodotRC] Sending notification: " + name)
	server.send(peer_id, JSON.stringify({"method": name, "params": data}))


func send_notification_to_all_peers(name: String, data) -> void:
	for peer in server.get_peers():
		send_notification(peer, name, data)
