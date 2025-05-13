@tool
class_name RemoteControlPlugin
extends EditorPlugin

var server: WebSocketServer
var previous_scene: Node


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
	var message = _message.strip_edges()
	print("[GodotRC] Received message: ", message)
	var parsed = JSON.parse_string(message)
	var params = parsed.params
	var response = null
	match parsed.method:
		"reload-resource":
			reload_resource(params)
		"get-scene-tree":
			response = get_scene_tree(params, peer_id, parsed.id)
		"insert-onready-variable":
			response = insert_onready_variable(params)
		"get-node-classes":
			response = get_node_classes()
		"create-scene":
			create_scene(params.path, params.base, params.name)
		"rename-node":
			rename_node(params.id, params.name)
		"wip":
			wip()
		_:
			push_warning("[GodotRC] Received unknown message: ", message)
	if response != null:
		send_response(peer_id, response, parsed.id)


func send_response(peer_id: int, data, response_id: int):
	server.send(peer_id, JSON.stringify({"result": data, "id": response_id}))


func send_notification(peer_id: int, name: String, data):
	server.send(peer_id, JSON.stringify({"method": name, "params": data}))


func reload_resource(path: String) -> void:
	ResourceLoader.load("res://first.gdshader", "", ResourceLoader.CACHE_MODE_REPLACE)


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
	# TODO: add user defined classes, we can get them from `ProjectSettings`
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


func get_editor_scenes_tabbar() -> TabBar:
	# TODO: check expected types of parents and children
	var n = get_editor_interface().get_editor_main_screen().get_parent().get_parent().get_children()
	var tabbar: TabBar = n[0].get_children()[0].get_children()[0].get_children()[0]
	return tabbar


# func something() -> void:
# 	var tabbar = get_editor_scenes_tabbar()
# 	get_editor_interface().open_scene_from_path("res://something.tscn")
# tabbar.set_current_tab(0)
# var a = get_editor_interface().get_edited_scene_root()
# print("AAAAA", get_editor_interface().get_edited_scene_root().scene_file_path)
# get_editor_interface().open_scene_from_path("res://level.tscn")
# var b = get_editor_interface().get_edited_scene_root()
# print("BBBBB", get_editor_interface().get_edited_scene_root().scene_file_path)
# print(get_editor_interface().get_open_scenes())
# print(a, b)
# tabbar.set_current_tab(1)


func something() -> void:
	# var tabbar = get_editor_scenes_tabbar()
	get_editor_interface().open_scene_from_path("res://something.tscn")
	# tabbar.set_current_tab(1)
	var root = get_editor_interface().get_edited_scene_root()
	print(root.scene_file_path)

	# var scene: PackedScene = load("res://something.tscn")
	# var state := scene.get_state()
	# print(state.get_node_property_value(0, 0))


func get_scene_tree(path: String, peer_id: int, response_id: int):
	get_editor_interface().open_scene_from_path("res://something.tscn")
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
	something()
	# var current_scene: String
	# if get_editor_interface().get_edited_scene_root():
	# 	current_scene = get_editor_interface().get_edited_scene_root().scene_file_path

	# open_scene_and_send_node_tree.call_deferred("res://something.tscn", current_scene)
	# var scene: PackedScene = load("res://level.tscn")
	# var inst = scene.instantiate()
	# var state := scene.get_state()
	# var tree: Dictionary = {}
	# print(state.get_node_count())
	# var classes = []
	# for cl in ClassDB.get_inheriters_from_class("Node"):
	# 	var api_type := ClassDB.class_get_api_type(cl)
	# 	print(cl, api_type)
	# if api_type == ClassDB.APIType.API_CORE or api_type == ClassDB.APIType.API_EXTENSION:


func _on_scene_child_order_changed() -> void:
	notify_scene_change()
	print("child order changed")


func _on_scene_tree_entered() -> void:
	notify_scene_change()
	print("tree entered")


func _on_replace_by(_node: Node) -> void:
	notify_scene_change()
	print("replaced by")


func _on_node_renamed() -> void:
	notify_scene_change()
	print("node renamed")


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


func rename_node(id: int, name: String) -> void:
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
