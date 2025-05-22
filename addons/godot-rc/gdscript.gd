@tool
class_name GRCCommandsGdscript
extends Node

var grc: GodotRC


func register_commands() -> void:
	grc.register_command("get-nodes-for-onready", get_nodes_for_onready, true)


func get_nodes_for_onready(path: String) -> Array:
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
