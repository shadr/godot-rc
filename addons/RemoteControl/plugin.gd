@tool
class_name RemoteControlPlugin
extends EditorPlugin

var server: WebSocketServer
var previous_scene: Node

var METHODS: Array = [
	["reload-resource", reload_resource, false],
	["get-scene-tree", get_scene_tree, true],
	["insert-onready-variable", insert_onready_variable, true],
	["get-node-classes", get_node_classes, true],
	["create-scene", create_scene, false],
	["rename-node", rename_node, false],
	["wip", wip, false]
]


func _enter_tree() -> void:
	server = WebSocketServer.new()
	add_child(server)
	server.listen(6500)
	server.message_received.connect(on_message)
	server.client_connected.connect(on_connected)

	scene_changed.connect(_on_scene_changed)


func _exit_tree() -> void:
	server.stop()
	server.queue_free()

	scene_changed.disconnect(_on_scene_changed)


func on_connected(peer_id: int) -> void:
	print("[GodotRC] Client connected: ", peer_id)


func on_message(peer_id: int, _message: String) -> void:
	var message: String = _message.strip_edges()
	print("[GodotRC] Received message: ", message)
	var parsed: Dictionary = JSON.parse_string(message)
	var params = parsed.params
	var response = null
	var known_method: bool = false
	for method in METHODS:
		var method_name: String = method[0]
		if parsed.method == method_name:
			known_method = true
			var callable: Callable = method[1]
			var with_response: bool = method[2]
			if with_response:
				response = callable.call(params)
			else:
				callable.call(params)
	if not known_method:
		push_warning("[GodotRC] Received unknown message: ", message)
	if response != null:
		send_response(peer_id, response, parsed.id)


func send_response(peer_id: int, data, response_id: int):
	server.send(peer_id, JSON.stringify({"result": data, "id": response_id}))


func send_notification(peer_id: int, name: String, data):
	server.send(peer_id, JSON.stringify({"method": name, "params": data}))


func reload_resource(path: String) -> void:
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


func insert_onready_variable(path: String) -> Array:
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


func get_node_classes(_params) -> PackedStringArray:
	# TODO: add user defined classes, we can get them from `ProjectSettings`
	var classes = ClassDB.get_inheriters_from_class("Node")
	return classes


func create_scene(params: Dictionary) -> void:
	var path: String = params.path
	var base: String = params.base
	var name: String = params.name

	var root: Node = ClassDB.instantiate(base)
	root.name = name
	var scene := PackedScene.new()
	var result = scene.pack(root)
	if result == OK:
		ResourceSaver.save(scene, path)


func get_editor_scenes_tabbar() -> TabBar:
	# TODO: check expected types of parents and children
	var n = get_editor_interface().get_editor_main_screen().get_parent().get_parent().get_children()
	var tabbar: TabBar = n[0].get_children()[0].get_children()[0].get_children()[0]
	return tabbar


func get_scene_tree(path: String):
	get_editor_interface().open_scene_from_path(path)
	var root = get_editor_interface().get_edited_scene_root()
	var tree = get_node_tree(root)
	return tree


func get_node_tree(node: Node) -> Dictionary:
	var parent = null
	if node.get_parent():
		parent = node.get_parent().get_instance_id()
	var children: Array = []
	for child in node.get_children():
		children.push_back(get_node_tree(child))
	var tree = {
		"name": node.name,
		"type": node.get_class(),
		"children": children,
		"id": node.get_instance_id(),
	}
	return tree


func wip() -> void:
	get_editor_interface().open_scene_from_path("res://something.tscn")
	var root = get_editor_interface().get_edited_scene_root()
	print(root.scene_file_path)


func _on_scene_child_order_changed() -> void:
	notify_scene_change()


func _on_scene_tree_entered() -> void:
	notify_scene_change()


func _on_replace_by(_node: Node) -> void:
	notify_scene_change()


func _on_node_renamed() -> void:
	notify_scene_change()


func notify_scene_change() -> void:
	for peer in server.get_peers():
		var scene_path := get_editor_interface().get_edited_scene_root().scene_file_path
		send_notification(peer, "scene-changed", scene_path)


func connect_signals(node: Node, recursive: bool = false) -> void:
	if node == null:
		return
	if not node.child_order_changed.is_connected(_on_scene_child_order_changed):
		node.child_order_changed.connect(_on_scene_child_order_changed)
	if not node.replacing_by.is_connected(_on_replace_by):
		node.replacing_by.connect(_on_replace_by)
	if not node.renamed.is_connected(_on_node_renamed):
		node.renamed.connect(_on_node_renamed)
	node.replacing_by.connect(
		func(n):
			disconnect_signals(node)
			connect_signals(n)
	)
	if recursive:
		for child in node.get_children():
			connect_signals(child, true)


func disconnect_signals(node: Node, recursive: bool = false) -> void:
	if node == null:
		return
	if node.child_order_changed.is_connected(_on_scene_child_order_changed):
		node.child_order_changed.disconnect(_on_scene_child_order_changed)
	if node.replacing_by.is_connected(_on_replace_by):
		node.replacing_by.disconnect(_on_replace_by)
	if node.renamed.is_connected(_on_node_renamed):
		node.renamed.disconnect(_on_node_renamed)
	if recursive:
		for child in node.get_children():
			disconnect_signals(child, true)


func rename_node(params: Dictionary) -> void:
	var id: int = params.id
	var name: String = params.name

	var node: Node = instance_from_id(id)
	node.name = name
	node.renamed.emit()
	get_editor_interface().mark_scene_as_unsaved()


# func get_scene_root_of_node(node: Node) -> Node:
# 	while node:
# 		if node.scene_file_path:
# 			return node
# 		node = node.get_parent()
# 	return null


func _on_scene_changed(scene_root: Node):
	if previous_scene:
		disconnect_signals(previous_scene, true)
	connect_signals(scene_root, true)
	previous_scene = scene_root
