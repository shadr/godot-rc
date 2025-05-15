@tool
class_name RemoteControlPlugin
extends EditorPlugin

# TODO: connect scene_opened signal
# TODO: add undo-redo history

var server: WebSocketServer
var previous_scene: Node

var METHODS: Array = [
	["reload-resource", reload_resource, false],
	["get-scene-tree", get_scene_tree, true],
	["insert-onready-variable", insert_onready_variable, true],
	["get-node-classes", get_node_classes, true],
	["create-scene", create_scene, false],
	["rename-node", rename_node, false],
	["save-scene", save_scene, false],
	["move-node", move_node, true],
	["remove-node", remove_node, false],
	["node-change-type", node_change_type, false],
	["node-add", node_add, false],
	["node-duplicate", node_duplicate, false],
	["wip", wip, false],
]

var need_to_notify_scene_change := false


func _process(_delta: float) -> void:
	if need_to_notify_scene_change:
		need_to_notify_scene_change = false
		notify_scene_change()


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
	Log.INFO("[GodotRC] Client connected: " + str(peer_id))


func on_message(peer_id: int, _message: String) -> void:
	var message: String = _message.strip_edges()
	Log.TRACE("[GodotRC] Received message: " + message)
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
		Log.WARN("[GodotRC] Received unknown message: " + message)
	if response != null:
		send_response(peer_id, response, parsed.id)


func send_response(peer_id: int, data, response_id: int):
	server.send(peer_id, JSON.stringify({"result": data, "id": response_id}))


func send_notification(peer_id: int, name: String, data):
	Log.TRACE("[GodotRC] Sending notification: " + name)
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
	var scene_file_path = ProjectSettings.globalize_path(node.scene_file_path)
	if scene_file_path:
		tree.scene_absolute_path = scene_file_path
		tree.scene_res_path = node.scene_file_path
	var script = node.get_script()
	if script:
		tree.script_path = script.get_path()
	return tree


func wip(_params) -> void:
	# var editor_node: Node = get_node("/root").find_child("*EditorNode*", false, false)
	# editor_node.push_item(null)
	# print(editor_node.scene_root)
	var root: Node = get_editor_interface().get_edited_scene_root()
	print(root.get_parent().get_children())
	# print(root, " owned by ", root.owner)
	# for child in root.get_children():
	# 	print(child, " owned by ", child.owner)
	# 	for child2 in child.get_children():
	# 		print(child2, " owned by ", child2.owner)
	# get_editor_interface().open_scene_from_path("res://something.tscn")
	# var node = root.find_child("asdf")
	# var node2d = Node2D.new()
	# node2d.set("transform", node.transform)
	# print(node.transform)
	# root.add_child(node2d)
	# node2d.owner = root


func _on_scene_child_order_changed() -> void:
	need_to_notify_scene_change = true


func _on_scene_tree_entered() -> void:
	need_to_notify_scene_change = true


func _on_replace_by(_node: Node) -> void:
	need_to_notify_scene_change = true


func _on_node_renamed() -> void:
	need_to_notify_scene_change = true


func notify_scene_change() -> void:
	for peer in server.get_peers():
		var scene_path := get_editor_interface().get_edited_scene_root().scene_file_path
		scene_path = ProjectSettings.globalize_path(scene_path)
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


func _on_scene_changed(scene_root: Node) -> void:
	if previous_scene:
		disconnect_signals(previous_scene, true)
	connect_signals(scene_root, true)
	previous_scene = scene_root


func save_scene(_params) -> void:
	get_editor_interface().save_scene()


func move_node(params: Dictionary) -> int:
	var parent_id: int = params.parent
	var node_id: int = params.node
	var index: int = params.index
	var silent: bool = params.get("silent", false)

	var parent: Node = instance_from_id(parent_id)
	var node: Node = instance_from_id(node_id)
	if node.get_parent() != parent:
		node.reparent(parent)
	parent.move_child(node, index)
	get_editor_interface().mark_scene_as_unsaved()
	return node.get_instance_id()


func remove_node(node_id: int) -> void:
	var node: Node = instance_from_id(node_id)
	node.queue_free()
	get_editor_interface().mark_scene_as_unsaved()


func node_change_type(params: Dictionary) -> void:
	var node_id: int = params.node_id
	var new_type: String = params.new_type
	var editor_node = get_node("/root").find_child("*EditorNode*", false, false)

	var old_node: Node = instance_from_id(node_id)
	var new_node: Node = ClassDB.instantiate(new_type)

	# # TODO: check custom types
	var default_old_node: Node = ClassDB.instantiate(old_node.get_class())

	var prop_list = old_node.get_property_list()
	for prop in prop_list:
		if prop.usage & PROPERTY_USAGE_STORAGE == 0:
			continue

		var default_val: Variant = default_old_node.get(prop.name)
		if default_val != old_node.get(prop.name):
			new_node.set(prop.name, old_node.get(prop.name))
	default_old_node.free()

	editor_node.push_item(null)

	var signals := old_node.get_signal_list()
	for sl in signals:
		var connection_list = old_node.get_signal_connection_list(sl.name)

		for connection in connection_list:
			if connection.flags & CONNECT_PERSIST == 0:
				continue

			new_node.connect(sl.name, connection.callable, CONNECT_PERSIST)

	new_node.set_name(old_node.name)

	connect_signals(new_node)

	# TODO: remember size of anchored control

	var is_scene_root = old_node == get_editor_interface().get_edited_scene_root()

	if is_scene_root:
		editor_node.set_edited_scene(new_node)

	# TODO: think about when to free old_node, because currently we are leaking memory
	# TODO: fix: Condition "p_node->data.parent" is true. p_node here is new_node
	old_node.replace_by(new_node, true)

	if is_scene_root:
		# TODO: fix: Condition "!is_inside_tree()" is true. Returning: Transform3D()
		for child in old_node.get_children():
			child.owner = null
			child.reparent(new_node)
			set_owner_recursively(child, new_node)

	for child in new_node.get_children():
		child.call("set_transform", child.call("get_transform"))

	editor_node.push_item(new_node)

	need_to_notify_scene_change = true

	if (
		is_scene_root
		&& get_editor_interface().get_edited_scene_root().get_parent().get_child_count() > 0
	):
		Log.WARN("[GodotRC] Editor SubViewport has multiple child nodes!")


func set_owner_recursively(node: Node, owner) -> void:
	node.owner = owner
	for child in node.get_children():
		set_owner_recursively(child, owner)


func node_add(params: Dictionary) -> void:
	var parent_id: int = params.parent_id
	var index: int = params.index
	var type: String = params.type

	var parent: Node = instance_from_id(parent_id)
	var new_node: Node = ClassDB.instantiate(type)
	new_node.name = type

	connect_signals(new_node)
	parent.add_child(new_node, true)
	parent.move_child(new_node, index)
	if parent == get_editor_interface().get_edited_scene_root():
		new_node.owner = parent
	else:
		new_node.owner = parent.owner
	get_editor_interface().mark_scene_as_unsaved()


func node_duplicate(node_id: int) -> void:
	var node: Node = instance_from_id(node_id)
	if node == get_editor_interface().get_edited_scene_root():
		return

	var new_node: Node = node.duplicate()
	var parent = node.get_parent()
	parent.add_child(new_node, true)
	parent.move_child(new_node, node.get_index() + 1)

	connect_signals(new_node, true)

	set_owner_recursively(new_node, node.owner)

	need_to_notify_scene_change = true
