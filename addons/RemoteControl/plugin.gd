@tool
extends EditorPlugin

var server: WebSocketServer


func _enter_tree() -> void:
	server = WebSocketServer.new()
	add_child(server)
	server.listen(6500)
	server.message_received.connect(on_message)
	server.client_connected.connect(on_connected)


func _exit_tree() -> void:
	server.stop()
	server.queue_free()


func on_connected(peer_id: int) -> void:
	print("[GodotRC] Client connected: ", peer_id)


func on_message(peer_id: int, _message: String) -> void:
	var message = _message.strip_edges()
	print("[GodotRC] Received message: ", message)
	var parsed = JSON.parse_string(message)
	var params = parsed.params
	var response = null
	match parsed.method:
		"reload-resource":
			reload_resource(params)
		# "get-scene-tree":
		# 	response = get_scene_tree(parsed.params)
		"insert-onready-variable":
			response = insert_onready_variable(params)
		"get-node-classes":
			response = get_node_classes()
		"create-scene":
			create_scene(params.path, params.base, params.name)
		"wip":
			wip()
		_:
			push_warning("[GodotRC] Received unknown message: ", message)
	if response != null:
		send_response(peer_id, response, parsed.id)


func send_response(peer_id: int, data, response_id: int):
	server.send(peer_id, JSON.stringify({"result": data, "id": response_id}))


func reload_resource(path: String) -> void:
	ResourceLoader.load("res://first.gdshader", "", ResourceLoader.CACHE_MODE_REPLACE)


# func get_scene_tree(peer_id: int, path, response_id: int):
# 	var scene: PackedScene = load(path)
# 	var inst: Node = scene.instantiate()
# 	var tree: Dictionary = {}
# 	get_node_tree(inst, tree)
# 	send_response(peer_id, tree, response_id)
# 	inst.queue_free()

# func get_node_tree(node: Node, tree: Dictionary):
# 	var parent = null
# 	if node.get_parent():
# 		parent = node.get_parent().get_instance_id()
# 	tree[node.get_instance_id()] = {
# 		"name": node.name,
# 		"type": node.get_class(),
# 		"parent": parent,
# 	}
# 	for child in node.get_children():
# 		get_node_tree(child, tree)


func insert_onready_variable(path) -> Array:
	var scene: PackedScene = load(path)
	var state: SceneState = scene.get_state()
	var node_count := state.get_node_count()
	var nodes = []
	for i in node_count:
		var node_path = state.get_node_path(i)
		var type = state.get_node_type(i)
		var node_name = state.get_node_name(i)
		nodes.push_back({"path": node_path, "type": type, "name": node_name})
	return nodes


func get_node_classes() -> PackedStringArray:
	var classes = ClassDB.get_inheriters_from_class("Node")
	# for cl in
	# 	var api_type := ClassDB.class_get_api_type(cl)
	# 	classes.append(cl)
	return classes


func create_scene(path: String, base: String, name: String) -> void:
	var root: Node = ClassDB.instantiate(base)
	root.name = name
	var scene := PackedScene.new()
	var result = scene.pack(root)
	if result == OK:
		ResourceSaver.save(scene, path)


func wip() -> void:
	var classes = []
	for cl in ClassDB.get_inheriters_from_class("Node"):
		var api_type := ClassDB.class_get_api_type(cl)
		print(cl, api_type)
		# if api_type == ClassDB.APIType.API_CORE or api_type == ClassDB.APIType.API_EXTENSION:
