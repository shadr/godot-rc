@tool
class_name RemoteControlPlugin
extends EditorPlugin

var server: WebSocketServer


func _enter_tree() -> void:
	server = WebSocketServer.new()
	server.plugin = self
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
			get_scene_tree(params, peer_id, parsed.id)
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
	var tabbar = get_editor_scenes_tabbar()
	tabbar.set_current_tab(1)
	var root = get_editor_interface().get_edited_scene_root()
	print(root.scene_file_path)

	# var scene: PackedScene = load("res://something.tscn")
	# var state := scene.get_state()
	# print(state.get_node_property_value(0, 0))


func get_scene_tree_helper(path: String, peer_id: int, response_id: int):
	get_editor_interface().open_scene_from_path("res://something.tscn")
	var root = get_editor_interface().get_edited_scene_root()
	send_response(peer_id, root.get_instance_id(), response_id)


func get_scene_tree(path: String, peer_id: int, response_id: int):
	get_scene_tree_helper.call_deferred(path, peer_id, response_id)
	# var scene: PackedScene = load(path)
	# var state := scene.get_state()
	# var tree: Dictionary = {}
	# get_node_tree(inst, tree)


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


func _on_scene_changed(scene_root: Node):
	print("Scene changed: ", scene_root.scene_file_path)
