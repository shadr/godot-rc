@tool
class_name GRCCommandsInspector
extends Node

var grc: GodotRC


func register_commands() -> void:
	grc.register_command("object-properties", get_object_properties, true)
	grc.register_command("inspector-change-property", change_property)
	grc.register_command("inspector-query-node-paths", query_node_paths, true)


func get_object_properties(params: Dictionary) -> Array:
	var object_id: int
	if params.object_id is String:
		object_id = int(params.object_id)
	else:
		object_id = params.object_id
	var opened: Array
	if params.has("opened_props") and params.opened_props is Array:
		opened = params.opened_props.map(func(element): return int(element))
	else:
		opened = []

	var object: Object = instance_from_id(object_id)
	return collect_object_properties(object, opened)


func collect_object_properties(object: Object, opened: Array) -> Array:
	var default_object: Object = ClassDB.instantiate(object.get_class())

	var prop_list = object.get_property_list()
	var res = []
	var where_to_push = [res]
	var group_prefixes = [""]
	var script = null
	for prop in prop_list:
		if prop.name == "script":
			script = prop
			continue
		var tusage = (
			prop.usage & (PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY)
		)
		if tusage:
			var grouping_index = -1
			match tusage:
				PROPERTY_USAGE_SUBGROUP:
					grouping_index = 3
				PROPERTY_USAGE_GROUP:
					grouping_index = 2
				PROPERTY_USAGE_CATEGORY:
					grouping_index = 1
			where_to_push.resize(grouping_index)
			group_prefixes.resize(where_to_push.size())
			if prop.name != "":
				var grouping = {"name": prop.name, "children": []}
				where_to_push.back().push_back(grouping)
				group_prefixes.push_back(prop.hint_string)
				where_to_push.push_back(grouping.children)
			else:
				where_to_push.push_back([])
			continue
		while where_to_push.size() > 2 && not prop.name.begins_with(group_prefixes.back()):
			where_to_push.pop_back()
			group_prefixes.pop_back()
		if prop.usage & PROPERTY_USAGE_EDITOR:
			var visible_name: String = prop.name.capitalize()

			if !group_prefixes.is_empty():
				visible_name = (
					visible_name.trim_prefix(group_prefixes.back().capitalize()).trim_prefix(" ")
				)
			var value = object.get(prop.name)
			var default_val = default_object.get(prop.name)
			var non_default = default_val != value
			if prop.type == TYPE_OBJECT:
				if value:
					var id = value.get_instance_id()
					if id in opened:
						prop.children = collect_object_properties(value, opened)
					value = id
				else:
					value = null
			elif prop.type == TYPE_AABB:
				value = [
					value.position.x,
					value.position.y,
					value.position.z,
					value.size.x,
					value.size.y,
					value.size.z
				]
			elif prop.type == TYPE_NODE_PATH and not value.is_empty():
				var target_node: Node = object.get_node(value)
				prop.additional_info = {
					"name": target_node.name,
					"type": target_node.get_class(),
				}
			prop.property = prop.name
			prop.visible_name = visible_name
			prop.value = value
			prop.non_default = non_default

			where_to_push.back().push_back(prop)
	if script:
		var non_default = object.get_script() != null
		script.property = script.name
		script.visible_name = "Script"
		script.value = object.get_script()
		script.non_default = object.get_script() != null
		res[0].children.push_back(script)
	res.reverse()

	return res


func change_property(params: Dictionary) -> void:
	var object_id: int = params.object_id
	var property = params.property
	var value = params.value

	var object = instance_from_id(object_id)

	if property is String:
		object.set(property, value)
	elif property is Array:
		var prop_path = ":".join(property)
		object.set_indexed(prop_path, value)

	grc.send_notification_to_all_peers(
		"property-changed", {"object": object_id, "property": property, "value": value}
	)


func query_node_paths(params: Dictionary) -> Array:
	var object_id: int = params.object_id
	var classes: Array = params.classes

	var object: Node = instance_from_id(object_id)

	# REVIEW: is it really correct that owner of a node in an editor always a scene root ?
	var scene_root: Node = object.owner

	var suitable_nodes = {}
	for cl in classes:
		for child in scene_root.find_children("*", cl):
			suitable_nodes[child] = null
	var paths = []
	for node in suitable_nodes.keys():
		paths.push_back(object.get_path_to(node))

	return paths
