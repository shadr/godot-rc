@tool
class_name GRCCommandsScene
extends Node

signal need_connect_signals(node: Node, recursive: bool)
signal scene_modified

var grc: GodotRC
var plugin: EditorPlugin:
	set(value):
		plugin = value
		editor_interface = plugin.get_editor_interface()
var editor_interface: EditorInterface


func register_commands() -> void:
	grc.register_command("scene-new", create_scene)
	grc.register_command("scene-tree", get_scene_tree, true)
	grc.register_command("scene-save", save_scene)
	grc.register_command("node-rename", rename_node)
	grc.register_command("node-move", move_node, true)
	grc.register_command("node-remove", remove_node)
	grc.register_command("node-change-type", node_change_type)
	grc.register_command("node-add", node_add)
	grc.register_command("node-duplicate", node_duplicate)


func create_scene(params: Dictionary) -> void:
	var path: String = params.path
	var base: String = params.base
	var name: String = params.name

	var root: Node = ClassDB.instantiate(base)
	root.name = name
	var scene := PackedScene.new()
	var result := scene.pack(root)
	if result == OK:
		ResourceSaver.save(scene, path)


func get_scene_tree(path: String) -> Dictionary:
	editor_interface.open_scene_from_path(path)
	var root: Node = editor_interface.get_edited_scene_root()
	var tree := get_node_tree(root)
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


func save_scene() -> void:
	editor_interface.save_scene()


func rename_node(params: Dictionary) -> void:
	var id: int = params.id
	var name: String = params.name

	var node: Node = instance_from_id(id)
	node.name = name
	node.renamed.emit()
	editor_interface.mark_scene_as_unsaved()


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
	editor_interface.mark_scene_as_unsaved()
	return node.get_instance_id()


func remove_node(node_id: int) -> void:
	var node: Node = instance_from_id(node_id)
	node.queue_free()
	editor_interface.mark_scene_as_unsaved()


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

	need_connect_signals.emit(new_node)

	# TODO: remember size of anchored control

	var is_scene_root = old_node == editor_interface.get_edited_scene_root()

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
			GodotRCPlugin.set_owner_recursively(child, new_node)

	for child in new_node.get_children():
		child.call("set_transform", child.call("get_transform"))

	editor_node.push_item(new_node)

	scene_modified.emit()

	if is_scene_root && editor_interface.get_edited_scene_root().get_parent().get_child_count() > 0:
		Log.WARN("[GodotRC] Editor SubViewport has multiple child nodes!")


func node_add(params: Dictionary) -> void:
	var parent_id: int = params.parent_id
	var index: int = params.index
	var type: String = params.type

	var parent: Node = instance_from_id(parent_id)
	var new_node: Node = ClassDB.instantiate(type)
	new_node.name = type

	need_connect_signals.emit(new_node)
	parent.add_child(new_node, true)
	parent.move_child(new_node, index)
	if parent == editor_interface.get_edited_scene_root():
		new_node.owner = parent
	else:
		new_node.owner = parent.owner
	editor_interface.mark_scene_as_unsaved()


func node_duplicate(node_id: int) -> void:
	var node: Node = instance_from_id(node_id)
	if node == editor_interface.get_edited_scene_root():
		return

	var new_node: Node = node.duplicate()
	var parent = node.get_parent()
	parent.add_child(new_node, true)
	parent.move_child(new_node, node.get_index() + 1)

	need_connect_signals.emit(new_node, true)

	GodotRCPlugin.set_owner_recursively(new_node, node.owner)

	scene_modified.emit()
