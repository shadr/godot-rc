@tool
class_name GRCCommandsMisc
extends Node

var grc: GodotRC


func register_commands() -> void:
	grc.register_command("resource-reload", resource_reload)
	grc.register_command("get-node-classes", get_node_classes, true)


func resource_reload(path: String) -> void:
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


func get_node_classes() -> PackedStringArray:
	# TODO: add user defined classes, we can get them from `ProjectSettings`
	var classes = ClassDB.get_inheriters_from_class("Node")
	return classes
