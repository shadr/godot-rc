@tool
class_name GodotRCPlugin
extends EditorPlugin

# TODO: connect scene_opened signal
# TODO: add undo-redo history
# TODO: feat: send error as response
# TODO: connect signals to current scene when plugin enabled
# TODO: fix: force readable name when moving nodes

var grc: GodotRC = null
var need_to_notify_scene_change := false


func _process(_delta: float) -> void:
	if need_to_notify_scene_change:
		need_to_notify_scene_change = false
		notify_scene_change()


func _enter_tree() -> void:
	grc = GodotRC.new()
	add_child(grc)

	var command_handlers = [
		GRCCommandsGdscript, GRCCommandsMisc, GRCCommandsScene, GRCCommandsInspector
	]
	for i in len(command_handlers):
		var handler_class = command_handlers[i]
		var handler: Node = handler_class.new()
		add_child(handler)
		handler.grc = grc
		handler.register_commands()
		command_handlers[i] = handler
	# Scene commands needs access to EditorPlugin methods
	command_handlers[2].plugin = self
	command_handlers[2].scene_modified.connect(_on_scene_modified)

	scene_changed.connect(_on_scene_changed)


func _exit_tree() -> void:
	grc.queue_free()
	scene_changed.disconnect(_on_scene_changed)


# called when scene modified by code that didn't trigger built-in signals
func _on_scene_modified() -> void:
	need_to_notify_scene_change = true


func _on_scene_child_order_changed() -> void:
	need_to_notify_scene_change = true


func _on_scene_tree_entered() -> void:
	need_to_notify_scene_change = true


func _on_replace_by(_node: Node) -> void:
	need_to_notify_scene_change = true


func _on_node_renamed() -> void:
	need_to_notify_scene_change = true


func notify_scene_change() -> void:
	var scene_path := get_editor_interface().get_edited_scene_root().scene_file_path
	scene_path = ProjectSettings.globalize_path(scene_path)
	grc.send_notification_to_all_peers("scene-changed", scene_path)


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


func _on_scene_changed(scene_root: Node) -> void:
	connect_signals(scene_root, true)


static func set_owner_recursively(node: Node, owner) -> void:
	node.owner = owner
	for child in node.get_children():
		set_owner_recursively(child, owner)
